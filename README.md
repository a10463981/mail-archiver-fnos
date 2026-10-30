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

## 卸载与数据：会删什么、不会删什么（实测结论）

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

## 数据目录说明（改目录 ≠ 搬数据）

- 数据默认放在系统分配的**共享目录**（`config/resource` 的 `data-share`），安装时由 fnOS 自动创建并授权，**不需要**手工授权或 `chown`。
- 想把数据放到数据盘（如 vol2），请在**安装向导**里指定；**运行期不支持热切换**（刻意设计，避免服务中断与数据搬家风险）。
- **改数据目录不会搬运已有数据**：新位置是空库（详见 `docs/DATA-DIRECTION.md`、`docs/DATA-DIR-SWITCH.md`）。换位置的正确顺序：**先 `pg_dump` 导出 → 卸载（选「保留数据」，别点「删除数据 / 清理」）→ 重装时指定新目录 → `pg_restore` 恢复**。

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
