# 数据目录：官方 `data-share` 范式（当前版本）

## 为什么改了
旧版让用户把数据目录指向自己的 `/vol1/1000/xxx`，于是要处理"目录是否已授权 → 是否可写 → 属主是否为 987"这一整条脆弱链路，并被迫引入"先默认装 → 授权 → 卸载 → 重装指定目录"的四步 SOP（中间那次卸载还会让平台删掉默认共享目录，反而更容易丢数据）。

**官方范式（`docs/core-concepts/resource.md`「共享数据目录」）**：
> 安装应用时，飞牛 fnOS 会**自动创建**声明的共享目录。这些目录使用 Windows ACL 权限模型…… **系统会自动为应用运行用户授予所需的 ACL 访问权限**。

当前版本的实现：
```json
// config/resource
{"data-share": {"shares": [{"name": "mail-archiver/data"}]}}
```
- 安装时系统建目录 + 授权给应用用户 `987`；
- 应用从平台注入的环境变量 `TRIM_DATA_SHARE_PATHS` 取数据根（冒号分隔取第一段，即 `${TRIM_DATA_SHARE_PATHS%%:*}`）；
- **不需要**用户在设置页授权、**不需要** `chown`、**不需要**二次重装。

## 卸载语义

| 卸载选项 | `@appdata` 应用自有目录 | `@appshare`（data-share 默认位置） | `/vol1/1000/...` 用户指定目录 | `.appstate` 快照 |
|---|---|---|---|---|
| **保留数据** | 保留 | **平台会删** | 平台不删 | 可能被删 |
| **删除数据** | 删 | **平台会删** | 平台不删 | 删 |

> **谁删了什么（实测结论，非推测）**：应用脚本只删应用自有目录 `@appdata/mail-archiver-fnos/data`（且仅当你选「删除数据」）；对 `@appshare` 只有读、唯一写操作是 `mkdir`。卸载窗口内 `@appshare` / `@appconf` / `@apphome` / `@appdata` 是**平台**按 `MAINEVENT DeleteFile` 依次清掉的（`uid=1000`，发生在 `app.uninstalling → APP_UNINSTALLED` 之间），**与「保留数据 / 删除数据」的选择无关**。
> **软件不做任何"自动清理用户数据"的动作**：删库、删目录一律由你手动执行。

### 保住数据的推荐做法

1. **重要数据放个人目录**：安装向导「数据目录（可选）」填 `/vol1/1000/mail-archive`（或 `/vol2/1000/mail-archive`）。平台卸载只清应用关联目录，**不删你自己的目录**。
2. **卸载 / 升级前先导出 dump**（数据在默认共享目录时尤其必要）：
   ```bash
   docker exec mail-archiver-fnos-db sh -c 'pg_dump -Fc -U mailarchiver -f /tmp/mailarchiver.dump mailarchiver'
   docker cp mail-archiver-fnos-db:/tmp/mailarchiver.dump /vol1/1000/mail-archive/backup-$(date +%F).dump
   ```
   若提示需要口令，用 `--show-db-password` 查看（只在终端显示，**勿贴聊天或截图**）。恢复：
   ```bash
   docker cp /vol1/1000/mail-archive/backup-2026-10-30.dump mail-archiver-fnos-db:/tmp/restore.dump
   docker exec mail-archiver-fnos-db sh -c 'pg_restore -U mailarchiver -d mailarchiver --clean --if-exists /tmp/restore.dump'
   ```
3. ⚠ **不要依赖「保留数据」这个选项来保住 share 里的数据**——卸载时平台会删 `@appshare/<app>`，与应用日志里"已保留"的提示无关。

## socket 落点（当前版本）

官方 `docs/core-concepts/gateway-registration.md`：
> `gatewaySocket` 只填写 Socket 文件名（如 app.sock）。**Socket 文件应放在已安装应用的 target 目录下。**

对应到打包层的真实值：

| 项 | 实际值 | 出处 |
|---|---|---|
| 容器监听的 socket | `LISTEN_UNIX_SOCKET=<TRIM_APPCENTER>/app.sock`（默认 `/vol1/@appcenter/mail-archiver-fnos/app.sock`） | `build/cmd/install_callback:31,238`、`build/app/docker/app.env` |
| 网关解析路径 | `/var/apps/<app>/target/app.sock`（`target` 为平台符号链接 → `@appcenter/<app>`，**同一 inode**） | 同上注释与安装期自检 |
| TCP 端口 | **不发布任何端口**（compose 无 `ports:`） | `build/app/docker/docker-compose.yaml` |
| 权限 | 启动后收紧为 `0600`（`main` 另有看护兜底） | `build/cmd/main` 的 `watch_socket()` |

安装期会自检：载荷 `app.env` 里的 `LISTEN_UNIX_SOCKET` 与网关解析路径不一致就**中止安装**（避免绑定失败 / 页面 404）。**不要把 socket 改到非 target 路径。**

## 官方 API（为什么不接）
`trim.file.checkUserACL` / `convertPath` / `getPlatformConfig` 实测返回 `200006 Internal Error`（当前系统不可用），且需要 `config/resource` 声明 `api-scope` + App≥1.34.0。改用 `data-share` 后**也已经不需要**它们。（研究记录未随本仓库发布。）

---

最后更新：**26.10.01**
