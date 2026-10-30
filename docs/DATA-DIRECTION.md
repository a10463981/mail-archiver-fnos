# 数据目录与卸载语义（重要）

应用只管理自己的**标准数据根**：`/vol1/@appdata/mail-archiver-fnos/data`。
数据默认来自系统分配的**共享目录**（`config/resource` 声明的 `data-share`，`/vol1/@appshare/<app>/data`），安装时由 fnOS 自动创建并授权。

如果你在安装向导里指定了别的目录（例如 `/vol2/1000/MailArchive`），标准数据根会成为一个**符号链接**：链接由应用管理，**目标目录由你管理**。

## 卸载时各是什么下场

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

## 换数据目录会发生什么

**当前版本不支持运行期热切换**（Docker 需要在容器启动时 bind 挂载），换位置只有一条路：

1. **先导出 dump**（数据在默认共享目录时**必须**，否则卸载后数据随平台删除一起消失）
2. **卸载**（应用中心；两种选项对 `@appshare` 的影响相同——都会被平台删除）
3. 重装时在向导的「数据目录（可选）」里填新目录（如 `/vol1/1000/mail-archive`）
4. 启动后把 dump 恢复到新库（`pg_restore`，见上方命令）
5. 新目录若是空的，装完就是空库（0 账号、0 邮件），属正常——把 dump 恢复进去才有旧邮件

> 一句话：**卸载时 `@appshare` 一定被平台删、`@appdata` 只有你选「删除数据」才删、`/vol1/1000/...` 你的目录平台不碰。想留住数据：装到个人目录，或先 dump。**
> 相关：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)、[`UPGRADE-UNINSTALL.md`](UPGRADE-UNINSTALL.md)、[`MULTI-DISK.md`](MULTI-DISK.md)

---

最后更新：**26.10.01**