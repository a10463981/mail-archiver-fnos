# 数据目录与卸载语义（重要）

应用只管理自己的**标准数据根**：`/vol1/@appdata/mail-archiver-fnos/data`。
数据默认来自系统分配的**共享目录**（`config/resource` 声明的 `data-share`，`/vol1/@appshare/<app>/data`），安装时由 fnOS 自动创建并授权。

如果你在安装向导里指定了别的目录（例如 `/vol2/1000/MailArchive`），标准数据根会成为一个**符号链接**：链接由应用管理，**目标目录由你管理**。

## 卸载与「删除数据」各是什么下场

| 操作 | `@appdata` 应用自有目录 | `@appshare`（data-share 默认位置） | `/vol1/1000/...` 用户指定目录 | `.appstate` 快照 |
|---|---|---|---|---|
| 卸载（选「保留数据」） | 保留 | **不删**（实测窗口内无删除事件） | 不删 | 可能被删 |
| 卸载（选「删除数据」） | 删 | **会被删**（实测 `MAINEVENT DeleteFile`） | 不删 | 删 |
| 应用中心「删除数据 / 清理」类操作 | 删 | **会被删**（实测 `MAINEVENT DeleteFile`） | 不删 | 删 |

> **谁删了什么（两次实测对照，非推测）**
> - **`08:58` 那次卸载**：整个窗口（08:50–09:30）**没有任何 `MAINEVENT DeleteFile`**，只有 `APP_UNINSTALLED`；`09:04` 重装直接复用同一份库 → **卸载本身不动 `@appshare`**。
> - **`00:04:48` 那次「删除数据 / 清理」**：出现 `MAINEVENT DeleteFile vol1/@appshare/mail-archiver`（`uid=1000`），同一批把 `@appconf` / `@apphome` / `@appdata` 一起删 → **删 share 的是「删除数据 / 清理」这类操作**。
> - 应用脚本本身**从不删 share**：代码里对 `@appshare` 只有 `mkdir`，`purge_standard_data_root` 只删 `${TRIM_PKGVAR}/data`；卸载时日志会打印"已保留数据 / 系统共享目录同样保留"。
> - ⚠ **应用日志说"已保留" ≠ 平台一定不删**：日志只证明应用脚本没删；平台侧要看有没有 `MAINEVENT DeleteFile`。两件事分开看。
> - **软件不做任何"自动清理用户数据"的动作**：删库、删目录一律由你手动执行。

### 保住数据的推荐做法

1. **重要数据放个人目录**：安装向导「数据目录（可选）」填 `/vol1/1000/mail-archive`（或 `/vol2/1000/mail-archive`）。平台对这类个人目录**不删**。
2. **重大操作前先导出 dump**（卸载 / 升级 / 清理之前都做）：
   ```bash
   docker exec mail-archiver-fnos-db sh -c 'pg_dump -Fc -U mailarchiver -f /tmp/mailarchiver.dump mailarchiver'
   docker cp mail-archiver-fnos-db:/tmp/mailarchiver.dump /vol1/1000/mail-archive/backup-$(date +%F).dump
   # 恢复
   docker cp /vol1/1000/mail-archive/backup-2026-10-30.dump mail-archiver-fnos-db:/tmp/restore.dump
   docker exec mail-archiver-fnos-db sh -c 'pg_restore -U mailarchiver -d mailarchiver --clean --if-exists /tmp/restore.dump'
   ```
   需要口令时用 `--show-db-password` 查看（只在终端显示，**勿贴聊天或截图**）。
3. ⚠ **不要依赖「保留数据」当备份**：它只说明应用脚本没删 `@appdata`，对 `@appshare` 不构成保证，也挡不住平台的「删除数据 / 清理」操作。**备份只能靠自己。**

## 换数据目录会发生什么

**当前版本不支持运行期热切换**（Docker 需要在容器启动时 bind 挂载），换位置只有一条路：

1. **先导出 dump**（换位置会得到空库，旧邮件要靠 dump 回来）
2. **卸载** → 选「**保留数据**」，**不要选「删除数据」、不要点「清理」**（卸载本身不动 `@appshare`，但"删除数据/清理"会删）
3. 重装时在向导的「数据目录（可选）」里填新目录（如 `/vol1/1000/mail-archive`）
4. 启动后把 dump 恢复到新库（`pg_restore`，见上方命令）
5. 新目录若是空的，装完就是空库（0 账号、0 邮件），属正常——把 dump 恢复进去才有旧邮件

> 一句话：**卸载本身不动 `@appshare`（实测无删除事件）；「删除数据 / 清理」会把 `@appshare` 一起删（实测 `MAINEVENT DeleteFile`）；`/vol1/1000/...` 个人目录平台不碰。想稳妥：装到个人目录，或操作前先 dump。**
> 相关：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)、[`UPGRADE-UNINSTALL.md`](UPGRADE-UNINSTALL.md)、[`MULTI-DISK.md`](MULTI-DISK.md)

---

最后更新：**26.10.01**