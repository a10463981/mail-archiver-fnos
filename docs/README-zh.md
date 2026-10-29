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
- **运行期不支持热切换**：Docker 需要在容器启动时 bind 挂载该目录，热切换意味着服务中断与搬数据风险。更换方式 = **卸载（保留数据）→ 重装时指定新目录**。
- 详细说明：[`DATA-DIR-SWITCH.md`](DATA-DIR-SWITCH.md)、[`DATA-DIRECTION.md`](DATA-DIRECTION.md)、[`MULTI-DISK.md`](MULTI-DISK.md)。

## 五、卸载语义（务必看清）

| 选项 | 应用自有数据根 `@appdata/mail-archiver-fnos/data` | 系统共享目录（`data-share`） | 你自己的存储目录（数据根为符号链接时） |
|---|---|---|---|
| **保留数据** | 保留 | 保留 | 保留链接与目标 |
| **删除数据** | 删除 | ⚠ **平台会连同 `data-share` 一起删除** | 只删符号链接本身，目标目录不动 |

> ⚠ **卸载前务必先备份**（`pg_dump` 或把整个数据目录复制到你自己的位置）。平台在「删除数据」时会一并删除共享目录，安装脚本无法拦截。

## 六、密码（两条不要混）

- **管理员登录密码**：网页/桌面登录用；只能重置，无法查看（库里只存哈希）。
- **数据库口令**：应用连 PostgreSQL 内部用，**与登录无关**；`--show-db-password` 给明文、`--show-db-fingerprint` 只给指纹，两者都不用于登录。
- 详情：[`PASSWORDS.md`](PASSWORDS.md)、[`FORGOT-PASSWORD.md`](FORGOT-PASSWORD.md)。

## 七、日志

```bash
docker logs --tail 200 mail-archiver-fnos      # 应用日志（唯一位置）
docker logs --tail 100 mail-archiver-fnos-db   # 数据库日志
```

`@appdata/mail-archiver-fnos/logs` 未使用（应用只写 stdout）；应用内「日志」页是访问审计，不是运行日志。更多见 [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)。

## 八、已知边界

见 [`KNOWN-ISSUES.md`](KNOWN-ISSUES.md)：免密登录真机覆盖待确认、跨用户隔离未验证、镜像层结构与上游不同、卸载删数据会连带 `data-share`。

## 九、版本号规则

```
<上游发布线>.<我方发布序号>
  上游发布线 = 26.10（上游官方 26.10.x）
  发布序号   = 01（首个正式发布；后续 02、03…）
```

历史 `0.1.x` 与开发期 `26.10.4x` 编号**仅作历史记录**，对应关系见 [`../VERSION-MAP.md`](../VERSION-MAP.md)，**请勿据此下载**（仓库只有 `26.10.01` 一个 Release）。

---

最后更新：**26.10.01**