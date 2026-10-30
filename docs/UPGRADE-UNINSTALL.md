# 升级与卸载（适用于 26.10.01）

## 升级

平台不支持命令行覆盖已装应用，升级 = **卸载 → 手动安装新包 → 启动**。注意：这会走平台卸载流程，**`@appshare`（默认数据位置）会被平台删除**。

> ⚠ **升级前必须先备份**：数据还在默认共享目录时，直接卸载升级 = 丢数据。先 `pg_dump` 导出（见下），或事先把数据目录指到个人目录再升级。

1. **导出 dump**（见「备份与恢复」）
2. 应用中心 → **卸载**（选哪个选项对 `@appshare` 影响相同，都会被平台删；选「保留数据」可保住 `@appdata` 私有目录）
3. 应用中心 → **手动安装** → 选新版本 `.fpk`；向导「数据目录（可选）」填 `/vol1/1000/...`（推荐，平台不删）或留空
4. **启动** → 恢复 dump（`pg_restore`）
5. 登录：沿用原有账号密码；若为全新库，向导密码生效（首登会强制改密）

注意事项：

- **不要手工变更 PostgreSQL 大版本**（本包固定 16）；跨大版本必须 dump/restore
- `@appconf` 下的数据库口令与加密密钥**同样会被平台在卸载时删除**，所以别把"只备份 `@appconf`"当成备份；真正的数据在 `pgdata`

## 卸载

| 卸载选项 | `@appdata` 应用自有目录 | `@appshare`（data-share 默认位置） | `/vol1/1000/...` 用户指定目录 | `.appstate` 快照 |
|---|---|---|---|---|
| **保留数据** | 保留 | **平台会删** | 平台不删 | 可能被删 |
| **删除数据** | 删 | **平台会删** | 平台不删 | 删 |

**谁删了什么（实测结论，非推测）**：应用脚本只删应用自有目录 `@appdata/mail-archiver-fnos/data`（且仅当你选「删除数据」）；对 `@appshare` 只有读、唯一写操作是 `mkdir`。卸载窗口内 `@appshare` / `@appconf` / `@apphome` / `@appdata` 是**平台**按 `MAINEVENT DeleteFile` 依次清掉的（`uid=1000`，发生在 `app.uninstalling → APP_UNINSTALLED` 之间），**与「保留数据 / 删除数据」的选择无关**。软件不做任何"自动清理用户数据"的动作：删库、删目录一律由你手动执行。

### 备份与恢复（卸载/升级前必做）

```bash
# 1) 导出（容器内 pg_dump -Fc，再把文件拷到你自己的目录）
docker exec mail-archiver-fnos-db sh -c 'pg_dump -Fc -U mailarchiver -f /tmp/mailarchiver.dump mailarchiver'
docker cp mail-archiver-fnos-db:/tmp/mailarchiver.dump /vol1/1000/mail-archive/backup-$(date +%F).dump

# 2) 恢复（装好新版本、应用启动后执行）
docker cp /vol1/1000/mail-archive/backup-2026-10-30.dump mail-archiver-fnos-db:/tmp/restore.dump
docker exec mail-archiver-fnos-db sh -c 'pg_restore -U mailarchiver -d mailarchiver --clean --if-exists /tmp/restore.dump'
```
若提示需要口令，用 `--show-db-password` 查看（只在终端显示，**勿贴聊天或截图**）。

补充说明：

- 容器停止时不带 `-v`，数据是 bind mount，不会随容器删除而消失；但**宿主机上的 `@appshare` 会被平台删除**，与容器无关
- 卸载会移除「访问权限」中的目录授权记录；重装后若要再用个人目录，需重新授权一次
- 个人目录（`/vol1/1000/...`）里的数据，平台卸载**不会删**；要清理请自己动手

## 相关文档

- 数据目录与卸载边界：[`DATA-DIRECTION.md`](DATA-DIRECTION.md)
- 数据目录范式与 socket 落点：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)
- 密码语义：[`PASSWORDS.md`](PASSWORDS.md)

---

最后更新：**26.10.01**
