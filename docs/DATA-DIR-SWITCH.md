# 数据目录：官方 `data-share` 范式（0.1.25 起）

## 为什么改了
旧版让用户把数据目录指向自己的 `/vol1/1000/xxx`，于是要处理"目录是否已授权 → 是否可写 → 属主是否为 987"这一整条脆弱链路，并被迫引入"先默认装 → 授权 → 卸载保留数据 → 重装指定目录"的四步 SOP。

**官方范式（`docs/core-concepts/resource.md`「共享数据目录」）**：
> 安装应用时，飞牛 fnOS 会**自动创建**声明的共享目录。这些目录使用 Windows ACL 权限模型…… **系统会自动为应用运行用户授予所需的 ACL 访问权限**。

所以 0.1.25 起：
```json
// config/resource
{"data-share": {"shares": [{"name": "mail-archiver/data"}]}}
```
- 安装时系统建目录 + 授权给应用用户 `987`；
- 应用通过 `TRIM_DATA_SHARE_PATHS`（或 `/var/apps/<app>/share/...`）拿到路径；
- **不需要**用户在设置页授权、**不需要** `chown`、**不需要**二次重装。

## 卸载语义
| 卸载选项 | 应用自有目录 `@appdata/<app>` | **共享目录（data-share）** | 目录记忆 |
|---|---|---|---|
| 删除数据 | 删 | **不删** | 清空 |
| 保留数据 | 保留 | **不删** | 保留 |

共享目录是**用户可见的数据**，误删代价高，所以两种卸载都**不删**；日志会打印其位置，如需清理请自行在文件管理器中删除。

## socket 落点（0.1.25 修正）
官方 `docs/core-concepts/gateway-registration.md`：
> `gatewaySocket` 只填写 Socket 文件名（如 app.sock）。**Socket 文件应放在已安装应用的 target 目录下。**

因此应用只监听 **`/var/apps/<app>/target/app.sock`**（`target → @appcenter/<app>`）。旧版曾把 socket 写到 `@appcenter` 裸路径，网关按 `target/app.sock` 解析时可能失败 → **页面 404**。**不要改回非 target 路径。**

## 官方 API（为什么不接）
`trim.file.checkUserACL` / `convertPath` / `getPlatformConfig` 实测返回 `200006 Internal Error`（当前系统不可用），且需要 `config/resource` 声明 `api-scope` + App≥1.34.0。改用 `data-share` 后**也已经不需要**它们。（研究记录未随本仓库发布。）
