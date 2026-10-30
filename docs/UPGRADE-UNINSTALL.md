# 升级与卸载（适用于 26.10.01）

## 升级

平台不支持命令行覆盖已装应用，升级 = **卸载 → 手动安装新包 → 启动**。

> ✅ **好消息（已实测）**：**单纯卸载不会删 `@appshare`**——`08:58` 那次卸载窗口内没有任何 `MAINEVENT DeleteFile`，重装直接复用了同一份库。
> ⚠ **但不要点「删除数据 / 清理」**：那是另一条路径，实测会连 `@appshare` 一起删。
> ⚠ **仍然建议先 `pg_dump`**：备份只能靠自己，日志里"已保留"只是应用脚本的说明，不构成平台保证。

1. **导出 dump**（见「备份与恢复」，5 分钟，值得）
2. 应用中心 → **卸载** → 选「**保留数据**」，**不要选「删除数据」**、不要点「清理」
3. 应用中心 → **手动安装** → 选新版本 `.fpk`；向导「数据目录（可选）」留空（沿用共享目录）或填 `/vol1/1000/...`（推荐，平台不删）
4. **启动** → 若能正常看到旧邮件，说明库复用了，无需恢复；否则 `pg_restore` 恢复 dump
5. 登录：沿用原有账号密码；若为全新库，向导密码生效（首登会强制改密）

注意事项：

- **不要手工变更 PostgreSQL 大版本**（本包固定 16）；跨大版本必须 dump/restore
- 别把"只备份 `@appconf`"当备份——真正的数据在 `pgdata`
- 应用日志里的"已保留数据 / 系统共享目录同样保留"只说明**应用脚本没删**；平台是否动过，要看有没有 `MAINEVENT DeleteFile`

## 卸载

| 操作 | `@appdata` 应用自有目录 | `@appshare`（data-share 默认位置） | `/vol1/1000/...` 用户指定目录 | `.appstate` 快照 |
|---|---|---|---|---|
| 卸载（选「保留数据」） | 保留 | **不删**（实测窗口内无删除事件） | 不删 | 可能被删 |
| 卸载（选「删除数据」） | 删 | **会被删**（实测 `MAINEVENT DeleteFile`） | 不删 | 删 |
| 应用中心「删除数据 / 清理」类操作 | 删 | **会被删**（实测 `MAINEVENT DeleteFile`） | 不删 | 删 |

**谁删了什么（两次实测对照，非推测）**

- `08:58` 那次卸载：整个窗口（08:50–09:30）**没有任何 `MAINEVENT DeleteFile`**，只有 `APP_UNINSTALLED`；`09:04` 重装直接复用同一份库 → **卸载本身不动 `@appshare`**。
- `00:04:48` 那次「删除数据 / 清理」：出现 `MAINEVENT DeleteFile vol1/@appshare/mail-archiver`（`uid=1000`），同一批把 `@appconf` / `@apphome` / `@appdata` 一起删 → **删 share 的是「删除数据 / 清理」这类操作**。
- 应用脚本本身**从不删 share**：代码里对 `@appshare` 只有 `mkdir`，`purge_standard_data_root` 只删 `${TRIM_PKGVAR}/data`；卸载时日志打印"已保留数据 / 系统共享目录同样保留"。
- ⚠ **应用日志说"已保留" ≠ 平台一定不删**：日志只证明应用脚本没删，平台侧要看有没有 `MAINEVENT DeleteFile`。
- **软件不做任何"自动清理用户数据"的动作**：删库、删目录一律由你手动执行。

### 备份与恢复（卸载 / 升级 / 清理前都做）

```bash
# 1) 导出（容器内 pg_dump -Fc，再把文件拷到你自己的目录）
docker exec mail-archiver-fnos-db sh -c 'pg_dump -Fc -U mailarchiver -f /tmp/mailarchiver.dump mailarchiver'
docker cp mail-archiver-fnos-db:/tmp/mailarchiver.dump /vol1/1000/mail-archive/backup-$(date +%F).dump

# 2) 恢复（装好新版本、应用启动后执行）
docker cp /vol1/1000/mail-archive/backup-2026-10-30.dump mail-archiver-fnos-db:/tmp/restore.dump
docker exec mail-archiver-fnos-db sh -c 'pg_restore -U mailarchiver -d mailarchiver --clean --if-exists /tmp/restore.dump'
```
若提示需要口令，用 `--show-db-password` 查看（只在终端显示，**勿贴聊天或截图**）。

> ⚠ **一句话警示**：**不要依赖「保留数据」当备份**——它只说明应用脚本没删 `@appdata`，对 `@appshare` 不构成保证，也挡不住平台的「删除数据 / 清理」。**备份只能靠自己。**

补充说明：

- 容器停止时不带 `-v`，数据是 bind mount，不会随容器删除而消失
- 卸载会移除「访问权限」中的目录授权记录；重装后若要再用个人目录，需重新授权一次
- 个人目录（`/vol1/1000/...`）里的数据，平台卸载**不会删**；要清理请自己动手

## 相关文档

- 数据目录与卸载边界：[`DATA-DIRECTION.md`](DATA-DIRECTION.md)
- 数据目录范式与 socket 落点：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)
- 密码语义：[`PASSWORDS.md`](PASSWORDS.md)

---

最后更新：**26.10.01**
