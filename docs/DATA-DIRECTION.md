# 数据目录与卸载语义（重要）

应用只管理自己的**标准数据根**：`/vol1/@appdata/mail-archiver-fnos/data`。
数据默认来自系统分配的**共享目录**（`config/resource` 声明的 `data-share`，`/vol1/@appshare/<app>/data`），安装时由 fnOS 自动创建并授权。

如果你在安装向导里指定了别的目录（例如 `/vol2/1000/MailArchive`），标准数据根会成为一个**符号链接**：链接由应用管理，**目标目录由你管理**。

## 卸载 / 清理各是什么下场（终版实测）

| 操作 | `@appdata` 应用自有目录 | `@appshare`（data-share 默认位置） | `/vol1/1000/...` 用户指定目录 |
|---|---|---|---|
| 卸载 · 保留数据 | 保留 | **不删**（实测无 DeleteFile） | 不删 |
| 卸载 · 删除数据 | 删（仅删链接与私有目录；目标不动） | **不删**（09:34 实测，`last_uninstall_action=delete`） | 不删 |
| 应用中心「删除数据 / 清理残留」 | 删 | **会被删**（22:10 / 22:34 / 22:44 / 00:04 四次实测） | 不删 |

> **结论（三次实测对照，无推断）**
> - **普通卸载（两种选项都算）不会删 `@appshare`**：`08:58`（保留数据）与 `09:34`（`last_uninstall_action=delete`）两次卸载窗口内**零 `DeleteFile`**；`09:34` 那次 `pgdata` 23 项、`PG_VERSION=16`、inode 463370 / Birth 00:06:24 均未变。
> - **删 share 的是「应用中心 → 删除数据 / 清理残留」类操作，或你手动删**：历史上 4 条 `DeleteFile`（`22:10:04`、`22:34:06`、`22:44:42`、`00:04:48`）都伴随 `@appconf` / `@apphome` / `@appdata` 同批删除。
> - 应用脚本只删私有目录与链接，日志逐字为 `已删除符号链接 /vol1/@appdata/…/data（目标 /vol1/@appshare/mail-archiver/data 保持不动，未删除）`——**这句日志可信（本次逐字验证）**；但**「清理残留」那类操作不看日志，直接删**。
> - **软件不做任何"自动清理用户数据"的动作**：删库、删目录一律由你手动执行。

### 保住数据的推荐做法（备份靠自己）

1. **重要数据放个人目录**：安装向导「数据目录（可选）」填 `/vol1/1000/mail-archive`（或 `/vol2/1000/mail-archive`）——这类个人目录平台不删，最省心。
2. **清理操作前先导出 dump**（普通卸载不丢数据，但下面这些会丢：应用中心「删除数据 / 清理残留」、你自己删目录、换目录后忘了恢复）：
   ```bash
   docker exec mail-archiver-fnos-db sh -c 'pg_dump -Fc -U mailarchiver -f /tmp/mailarchiver.dump mailarchiver'
   docker cp mail-archiver-fnos-db:/tmp/mailarchiver.dump /vol1/1000/mail-archive/backup-$(date +%F).dump
   # 恢复
   docker cp /vol1/1000/mail-archive/backup-2026-10-30.dump mail-archiver-fnos-db:/tmp/restore.dump
   docker exec mail-archiver-fnos-db sh -c 'pg_restore -U mailarchiver -d mailarchiver --clean --if-exists /tmp/restore.dump'
   ```
   需要口令时用 `--show-db-password` 查看（只在终端显示，**勿贴聊天或截图**）。
3. ⚠ **不要依赖「保留数据」当备份**：它只说明脚本保留了 `@appdata`；真正的保险是你自己导出的 dump。**会丢数据的不是普通卸载，而是「删除数据 / 清理残留」或你手动删目录。**

## 换数据目录会发生什么

**当前版本不支持运行期热切换**（Docker 需要在容器启动时 bind 挂载），换位置只有一条路：

1. **先导出 dump**（换位置会得到空库，旧邮件要靠 dump 回来）
2. **卸载**（保留数据/删除数据都可以——两种都不动 `@appshare`）；**不要点「清理残留」**
3. 重装时在向导的「数据目录（可选）」里填新目录（如 `/vol1/1000/mail-archive`）
4. 启动后把 dump 恢复到新库（`pg_restore`，见上方命令）
5. 新目录若是空的，装完就是空库（0 账号、0 邮件），属正常——把 dump 恢复进去才有旧邮件

> 一句话：**普通卸载（两种选项）都不删 `@appshare`（实测无 `DeleteFile`）；会删的是「应用中心 → 删除数据 / 清理残留」或你手动删；`/vol1/1000/...` 个人目录平台不碰。想稳妥：装到个人目录，或清理前先 dump。**
> 相关：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)、[`UPGRADE-UNINSTALL.md`](UPGRADE-UNINSTALL.md)、[`MULTI-DISK.md`](MULTI-DISK.md)

---

最后更新：**26.10.01**