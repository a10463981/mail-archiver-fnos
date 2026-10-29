# Mail-archiver for fnOS（mail-archiver-fnos）

**Mail-archiver 的 fnOS（飞牛 NAS）打包版**：`.fpk` 一键安装，在 NAS 上归档、检索个人与团队邮件。

> 当前版本：**26.10.01**（正式首发；版本号规则 `<上游发布线>.<我方发布序号>`，镜像基线上游 `39f59d2` = 官方 `26.10.1`）；对应表见 [`VERSION-MAP.md`](VERSION-MAP.md)。

- 上游项目：[s1t5/mail-archiver](https://github.com/s1t5/mail-archiver)（作者 **s1t5**），基线 commit **`39f59d2`**
- 本仓库是上游的 **fnOS 打包修改分发版**，修改内容全部以补丁形式给出（`patches/`），**按 GPL-3.0 分发**（见 [`LICENSE`](LICENSE)、[`NOTICE`](NOTICE)）
- 打包/发布：**a10463981**

## 前置条件

| 项 | 要求 |
|---|---|
| 系统 | fnOS **≥ 1.2.0401** |
| 架构 | **x86_64** |
| 内存 | 建议 **≥ 4GB**（应用 + PostgreSQL 容器） |
| 磁盘 | 按邮件量预留；数据库与附件都在数据目录内 |
| 网络 | 安装包**内嵌应用镜像**（离线 `docker load`），唯一联网点是拉取数据库镜像 `postgres:16-alpine` |

## 从 Releases 下载并安装（三步）

1. 打开 [**Releases**](https://github.com/a10463981/mail-archiver-fnos/releases)（当前只有 **`26.10.01`**）→ 下载 `mail-archiver-fnos-26.10.01.fpk` 和 `SHA256SUM.txt`。
2. **校验**（建议，应为 `969a54cd…`）：
   ```bash
   sha256sum -c SHA256SUM.txt        # Linux / macOS
   certutil -hashfile mail-archiver-fnos-26.10.01.fpk SHA256   # Windows
   ```
3. fnOS **应用中心 → 手动安装 → 选择 .fpk** → 向导填管理员账号 / 密码 / 时区 → 完成 → **启动** → 安装完成后从**桌面打开**应用。

> 安装向导里的「管理员密码」**仅用于首次建库**；若检测到已有数据（上次卸载选了「保留数据」），此密码不生效，请用原密码登录，或按 `docs/PASSWORDS.md` 重置。

## ⚠️ 安全提示

- **安装日志里的管理员口令是掩码形式**（如 `Ma****6!`），不含明文；口令在库里**只存哈希，无法查看、只能重置**（应用设置 → 运行设置 → 管理员登录密码）。
- **请勿截图或外传安装日志**；向他人求助排障时，先确认日志与截图中不含账号、口令、邮箱地址。
- 应用日志查看：`docker logs --tail 200 mail-archiver-fnos`（`data/logs` 虽已挂载但运行日志以 stdout 为主），详见 [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md)。

## 卸载：选「保留数据」还是「删除数据」

| 卸载选项 | 应用自有目录 `@appdata/mail-archiver-fnos/data` | 系统共享目录（data-share，`/vol1/@appshare/<app>/data`） | 你的存储空间目录（数据根是指向它的符号链接时） | 重装后 |
|---|---|---|---|---|
| **保留数据** | 保留（含旧数据库与账号） | 保留 | 保留链接与目标 | 沿用旧账号与旧密码；**向导密码不生效** |
| **删除数据** | 删除（数据库/附件清空） | ⚠ **平台会把 data-share 一并删除** | **只删符号链接本身，目标目录一个字节都不动** | 全新空库、全新账号 |

> ⚠ **重要提醒（实测）**：应用中心选「**删除数据**」时，平台会把 `data-share`（`/vol1/@appshare/<app>/data`）**一起删掉**（实测 `MAINEVENT DeleteFile`），安装脚本无法拦截。因此**卸载前务必先备份**（`pg_dump` 或整目录复制到你自己管理的位置）。

一句话：**「删除数据」删的永远是应用自己的东西；你自己目录里的数据只能你自己删——但默认共享目录请当作会被删，先备份。**
完整的卸载/升级语义见 [`docs/UPGRADE-UNINSTALL.md`](docs/UPGRADE-UNINSTALL.md) 与 [`docs/DATA-DIRECTION.md`](docs/DATA-DIRECTION.md)。

## 数据目录说明（改目录 ≠ 搬数据）

- 数据默认放在系统分配的**共享目录**（`config/resource` 的 `data-share`），安装时由 fnOS 自动创建并授权，**不需要**手工授权或 `chown`。
- 想把数据放到数据盘（如 vol2），请在**安装向导**里指定；**运行期不支持热切换**（刻意设计，避免服务中断与数据搬家风险）。
- **改数据目录不会搬运已有数据**：新位置是空库，旧数据仍在原处（详见 `docs/DATA-DIRECTION.md`、`docs/DATA-DIR-SWITCH.md`）。需要换位置时：先备份 → 卸载（保留数据）→ 重装时指定目录 → 按需手工迁移。

## 版本与可复现构建

- 版本 → 补丁序号 → 镜像 tag → sha256 对应表：[`VERSION-MAP.md`](VERSION-MAP.md)
- 复现该 fpk：`build/` 内包含 `Dockerfile`、`rebuild.sh`、`make-icons.sh`、`docker-compose.yaml`、`cmd/`（安装/升级/卸载/设置页脚本）、`config/`、`wizard/`、`manifest` 与图标。用法见 `build/rebuild.sh` 头部注释。
- 第三方组件许可：[`THIRD-PARTY-NOTICES`](THIRD-PARTY-NOTICES)

## 文档

| 文档 | 内容 |
|---|---|
| [`docs/INSTALL-zh.md`](docs/INSTALL-zh.md) | 安装说明（向导字段、首登改密、残留处理） |
| [`docs/PASSWORDS.md`](docs/PASSWORDS.md) | 密码语义三条 + 忘记密码的自救路径 |
| [`docs/UPGRADE-UNINSTALL.md`](docs/UPGRADE-UNINSTALL.md) | 升级与卸载语义 |
| [`docs/DATA-DIRECTION.md`](docs/DATA-DIRECTION.md) | 数据目录与「删除数据」的边界 |
| [`docs/DATA-DIR-SWITCH.md`](docs/DATA-DIR-SWITCH.md) | 数据目录范式（官方 `data-share`）与 socket 落点 |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | 日志位置、常见现象、健康指标 |
| [`docs/KNOWN-ISSUES.md`](docs/KNOWN-ISSUES.md) | 已知问题清单与边界 |
| [`docs/FORGOT-PASSWORD.md`](docs/FORGOT-PASSWORD.md) | 忘记密码 / 登录不上（含 CLI 兜底） |
| [`docs/MULTI-DISK.md`](docs/MULTI-DISK.md) | 系统盘 + 数据盘的多磁盘摆放 |
| [`docs/README-zh.md`](docs/README-zh.md) | 中文总览（版本事实、安装、数据、密码、日志） |

## 许可与免责

- 本仓库与其产出的 `.fpk` 均以 **GNU GPL-3.0** 分发；安装包内含上游程序的编译产物，对应源码获取方式见 [`NOTICE`](NOTICE)。
- 本分发版由第三方（a10463981）维护，**与上游作者无关**，上游作者不对本打包版提供支持。使用前请自行评估风险并做好数据备份。

---

最后更新：**26.10.01**（镜像 `zh-39f59d2-p30`，fpk 149,546,782 B，sha256 `969a54cd…`）
