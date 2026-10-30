# Mail-Archiver for fnOS · 中文说明

**Mail-Archiver 的 fnOS（飞牛 NAS）打包版**：一份 `.fpk` 安装包，装在自己的 NAS 上，用于归档与检索个人/团队邮件。

| 项 | 值 |
|---|---|
| 当前版本 | **26.10.01（正式首发）** |
| 版本号规则 | 上游 `26.10.x` 发布线 + 我方发布序号（首发 `01`，后续 `02`、`03`…） |
| 上游基线 | `s1t5/mail-archiver` @ **`39f59d2`**（官方 `26.10.1`） |
| 应用镜像 | `mail-archiver-fnos:zh-39f59d2-p30`（**已内嵌在 fpk 内**） |
| 安装包 | `mail-archiver-fnos-26.10.01.fpk`，149,546,782 B，sha256 `969a54cd6d815bed930db7a9b972646cf2df7560ab7637b50d3da6ab643dd0ad` |
| 许可 | GPL-3.0（见仓库 `LICENSE` / `NOTICE`） |
| 架构 | x86_64（`build/manifest` 记 `platform = x86`，fnOS 的 x86 即 x86_64）、`os_min_version = 1.2.0401` |

## 一、前置条件

- fnOS **≥ 1.2.0401**
- 架构 **x86_64**
- 内存建议 **≥ 4GB**
- 安装包内已内嵌应用镜像，安装时**离线 `docker load`**，无需从任何 registry 拉取；**唯一联网点是数据库镜像 `postgres:16-alpine`**（离线环境请先 `docker pull` 一次）

## 二、安装（三步）

1. 从 [Releases](https://github.com/a10463981/mail-archiver-fnos/releases) 下载 `.fpk` 与 `SHA256SUM.txt`，校验：`sha256sum -c SHA256SUM.txt`
2. 应用中心 → **手动安装** → 选 `.fpk` → 向导填管理员账号 / 密码 / 时区，数据目录可留空（走系统共享目录）
3. **启动** → 从桌面打开「邮件归档」

首次登录会停在「修改密码」页，属上游对初始密码的保护，改一次即可。

## 三、三个实用点

1. **装完即中文**：界面默认中文，语言可配置。
2. **登录 fnOS 后桌面点开就用**：应用通过 fnOS 网关的身份头识别当前用户，无需二次输入账号密码。本版修复网关头认证缺陷（中间件自取 `LISTEN_UNIX_SOCKET` 并校验 `0600`）；**真机覆盖仍在确认中，欢迎反馈**。
3. **忘记密码可自助重置**：应用中心 →「应用设置」→「运行设置」→「管理员登录密码」，保存即生效；详见 [`FORGOT-PASSWORD.md`](FORGOT-PASSWORD.md)。

## 四、数据目录

- 默认放在系统分配的**共享目录**（`data-share`），安装时由 fnOS 自动创建并授权，**不需要**手工授权或 `chown`。
- 想放到数据盘（如 `/vol2/1000/...`），在**安装向导**里指定即可。
- **运行期不支持热切换**：Docker 需要在容器启动时 bind 挂载该目录，热切换意味着服务中断与搬数据风险。更换方式 = **先 `pg_dump` 导出 → 卸载 → 重装时指定新目录 → `pg_restore` 恢复**。
- 详细说明：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)、[`DATA-DIRECTION.md`](DATA-DIRECTION.md)、[`MULTI-DISK.md`](MULTI-DISK.md)。

## 五、卸载与数据：会删什么、不会删什么（实测结论）

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

## 六、密码（两条不要混）

- **管理员登录密码**：网页/桌面登录用；只能重置，无法查看（库里只存哈希）。
- **数据库口令**：应用连 PostgreSQL 内部用，**与登录无关**；`--show-db-password` 给明文、`--show-db-fingerprint` 只给指纹，两者都不用于登录。
- 详情：[`PASSWORDS.md`](PASSWORDS.md)、[`FORGOT-PASSWORD.md`](FORGOT-PASSWORD.md)。

## 七、日志

```bash
docker logs --tail 200 mail-archiver-fnos      # 应用日志（唯一位置）
docker logs --tail 100 mail-archiver-fnos-db   # 数据库日志
```

`@appdata/mail-archiver-fnos/logs` 虽挂载到容器 `/data/logs`，但运行日志以 stdout 为主；应用内「日志」页是访问审计，不是运行日志。更多见 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)。

## 八、已知边界

见 [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md)：免密登录真机覆盖待确认、跨用户隔离未验证、镜像层结构与上游不同、卸载删数据会连带 `data-share`。

## 九、版本号规则

```
<上游发布线>.<我方发布序号>
  上游发布线 = 26.10（上游官方 26.10.x）
  发布序号   = 01（首个正式发布；后续 02、03…）
```

仓库当前**只有 `26.10.01` 一个 Release**；请按上面的规则识别版本，其余编号（旧编号或开发期编号）均已作废，不要据此寻找安装包。

---

最后更新：**26.10.01**