# 数据目录切换排障（0.1.18 起）

切换数据目录（设置 → 运行设置 → 指定目录）时遇到下面的现象，按对应条处理：

## ① 目录 `mode 0` / ACL 授权后仍报"不可写"

fnOS「应用设置 → 访问权限」给的是 **ACL 访问权，不等于改属主**；且部分存储卷 **ACL 不一定被强制生效**。
处理（首选改属主）：
```bash
sudo chown -R 987:982 /vol1/1000/<你的目录> && sudo chmod 755 /vol1/1000/<你的目录>
```
（987 是本应用的容器运行 UID；重装/迁机后若 UID 变了，以安装日志里提示的为准。）

## ② 切完应用是停着的 / "service postgres has no container to start"

旧版（<0.1.18）迁移失败只回滚、不重新拉起容器。0.1.18 起**失败也会自动重启并给出提示**；仍停着就点一次「启动」：
`appcenter-cli start mail-archiver-fnos`（或应用中心点启动）。

## ③ DB 报 `Permission denied`(secret) / `28P01 password authentication failed`

载荷里的数据库口令文件必须**非空且属主是应用用户**；否则 PostgreSQL 用空口令初始化 → 应用连不上 → 打开空白页。
0.1.18 起：保存配置时**始终写口令并修正属主**，且**检测到 28P01 会自动 ALTER ROLE 对齐并重启应用**。
手工对齐：
```bash
PW=$(sudo cat /vol1/@appconf/mail-archiver-fnos/pg_password)
docker exec -i mail-archiver-fnos-db psql -U mailarchiver -d postgres -c "ALTER ROLE mailarchiver WITH PASSWORD '$PW';"
docker restart mail-archiver-fnos
```

## ④ `SocketException(99)` 崩溃循环（Restarting 139）/ 载荷缺 compose

现象：应用容器 exit 139、日志 `Cannot assign requested address`；或平台报 `service "postgres" has no container to start`。
根因：载荷 `${TRIM_APPDEST}/docker/` 缺少 `docker-compose.yaml`，或 compose 没把 socket 目录挂进容器。
0.1.18 起 compose 已内置 `/vol1/@appcenter/<app>` 挂载、渲染时补齐 compose 文件。
若旧装仍需急救：
```bash
cp /vol1/@appcenter/mail-archiver-fnos/docker/docker-compose.yaml /var/apps/mail-archiver-fnos/docker/docker-compose.yaml
```
然后应用中心「启动」。

> 任何情况下都不要手动删除 `/vol1/1000/mail-data`、`/vol1/1000/cese123` 或 `@appdata/.../data.bak-*`（那是历史数据）。
