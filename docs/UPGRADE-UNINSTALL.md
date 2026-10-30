# 升级与卸载（适用于 26.10.01）

## 升级

平台不支持命令行覆盖已装应用，升级 = **卸载 → 手动安装新包 → 启动**。

> ✅ **已实测**：**普通卸载（「保留数据」和「删除数据」两种选项都算）都不会删 `@appshare`**——`08:58`（保留数据）与 `09:34`（`last_uninstall_action=delete`）两次卸载窗口内都是零 `DeleteFile`，重装直接复用同一份库。
> ⚠ **但不要走「应用中心 → 删除数据 / 清理残留」**：那条路径不看日志，直接删 `@appshare`（历史 4 次实测）。
> ⚠ **仍然建议先 `pg_dump`**：能丢数据的是"清理 / 手动删"，备份能兜住误操作——**备份只能靠自己**。

1. **导出 dump**（见「备份与恢复」，5 分钟，值得）
2. 应用中心 → **卸载**（保留数据/删除数据都可以，两者都不动 `@appshare`）；**不要点「清理残留」**
3. 应用中心 → **手动安装** → 选新版本 `.fpk`；向导「数据目录（可选）」留空（沿用共享目录）或填 `/vol1/1000/...`（推荐，平台不删）
4. **启动** → 若能正常看到旧邮件，说明库复用了，无需恢复；否则 `pg_restore` 恢复 dump
5. 登录：沿用原有账号密码；若为全新库，向导密码生效（首登会强制改密）

注意事项：

- **不要手工变更 PostgreSQL 大版本**（本包固定 16）；跨大版本必须 dump/restore
- 别把"只备份 `@appconf`"当备份——真正的数据在 `pgdata`
- 应用日志里的"已保留数据 / 系统共享目录同样保留"只说明**应用脚本没删**；平台是否动过，要看有没有 `MAINEVENT DeleteFile`

## 卸载

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

补充说明：

- 容器停止时不带 `-v`，数据是 bind mount，不会随容器删除而消失
- 卸载会移除「访问权限」中的目录授权记录；重装后若要再用个人目录，需重新授权一次
- 个人目录（`/vol1/1000/...`）里的数据，平台**不会删**；要清理请自己动手

## 相关文档

- 数据目录与卸载边界：[`DATA-DIRECTION.md`](DATA-DIRECTION.md)
- 数据目录范式与 socket 落点：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)
- 密码语义：[`PASSWORDS.md`](PASSWORDS.md)

---

最后更新：**26.10.01**
