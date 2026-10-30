# 排障（适用于 26.10.01）

## 日志在哪
```bash
docker logs --tail 200 mail-archiver-fnos        # 应用日志（唯一位置）
docker logs --tail 100 mail-archiver-fnos-db     # 数据库日志
```
- `@appdata/mail-archiver-fnos/logs` 已挂载到容器 `/data/logs`，但应用运行日志以 **stdout** 为主；排障请用上面的 `docker logs`
- 应用内「日志」页是**访问审计**（`AccessLogs` 表），不是应用运行日志

## 常见现象

| 现象 | 处理 |
|---|---|
| 装完提示「存在安装历史」 | 删除本应用残留后再装（只删这两个）：`/vol1/@apptemp/mail-archiver-fnos`、`/var/apps/mail-archiver-fnos` |
| 首次登录被要求改密 | **正常**（上游对初始密码的保护），改一次即可 |
| 登录后"重定向过多" | 已修复；若复现请附 `docker logs` 与浏览器 URL |
| 忘记密码 | 设置页「重置管理员登录密码」/ `--reset-password` / 网关故障先 `--unbind` |
| 后台功能"不动了"（同步/统计） | `docker logs mail-archiver-fnos 2>&1 \| grep -c "failed and will not continue"` >0 → 重启容器 |
| 应用起不来 | `docker ps -a`、`docker logs mail-archiver-fnos-db`、`df -h`、`ls -ld @appdata/mail-archiver-fnos/data/pgdata` |
| 卸载后 `@appshare/mail-archiver` 里的数据不见了 | **普通卸载不删 share**（`08:58` 保留数据、`09:34` 删除数据两次实测均零 `DeleteFile`）；若消失，多半是随后走了「删除数据 / 清理残留」或手工删过。能救的只有之前导出的 dump：装好后 `pg_restore`；以后把数据目录指到 `/vol1/1000/...` |
| 升级后发现邮件全没了 | 先确认是不是走了「应用中心 → 清理残留」（那才会删 `@appshare`）；再确认向导里数据目录是否指到了空目录。升级前建议 `pg_dump`（命令见 [`UPGRADE-UNINSTALL.md`](UPGRADE-UNINSTALL.md)） |

## 健康指标（正常使用时应为 0）
```bash
docker logs mail-archiver-fnos 2>&1 | grep -cE "session-identity-guard|identity-mixing-prevented|Re-issued session would change"
```
出现非 0 ⇒ 身份判定走了异常分支（换人时 `identity-mixing-prevented` 出现属正常）。

---

最后更新：**26.10.01**
