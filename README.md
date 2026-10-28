# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver)（.NET 邮件归档与检索服务）打包成 **飞牛 fnOS** 的安装包（`.fpk`）。

> ⚠️ 本仓库是上游项目的**修改分发版**，修改以补丁形式提供（`patches/`），同样以 **GPL-3.0** 分发。详见 [NOTICE](NOTICE) 与 [LICENSE](LICENSE)。

## 简介

- 从 fnOS 桌面点开即用：通过 fnOS 统一网关注入的身份实现**免密登录**，同时**保留密码通道**（双通道）
- 简体中文界面、时区按 `Asia/Shanghai` 显示
- 邮件归档/检索、EML/MBox 导入、审计日志、导出
- 容器以非 root 运行，**不发布任何 TCP 端口**，仅通过 unix socket 与网关通信

## 前置条件

| 项 | 要求 |
|---|---|
| fnOS 版本 | **≥ 1.2.0401**（实测 1.2.0800） |
| 架构 | **x86_64** |
| 内存 | 建议 **≥ 4 GB**（.NET + PostgreSQL 同机） |
| 磁盘 | 镜像约占 1 GB；数据按邮件量增长 |

## 安装（从 Releases 下载）

1. 打开本仓库 **Releases**，下载 `mail-archiver-fnos-<版本>.fpk` 与 `SHA256SUM.txt`
2. 校验：`shasum -a 256 mail-archiver-fnos-0.1.16.fpk`（与 `SHA256SUM.txt` 逐字符比对）
3. fnOS 桌面 → **应用中心** → **手动安装** → 选择该 `.fpk`
4. 向导：管理员用户名默认 `admin`；**密码（仅首次建库时生效）**——全新安装即初始密码，**首次登录必须改密一次（正常）**；若选「保留数据」重装则此密码不生效、请用原密码；数据目录建议改到你的存储空间；时区 `Asia/Shanghai`
5. 装完点**启动** → 桌面点「邮件归档」→ 登录

## 卸载与数据

| 卸载选项 | 结果 |
|---|---|
| **保留数据** | 数据留着，重装后账号密码照旧（**升级请选这个**） |
| **删除数据** | 删除**应用自有**的标准目录 `@appdata/mail-archiver-fnos/data`；若数据目录是指向存储空间的**符号链接**，则**只删链接，你的目录一字节不动** |

> 想让数据跨卸载长期保留：把数据目录改到存储空间（变成符号链接，卸载只删链接）。

## 🔑 密码语义（三条）

1. **全新安装**：初始密码 = 向导里填的那个；首次登录**必须改密一次**。
2. **保留数据重装**：向导里的密码**不生效**，用**原密码**。
3. **密码只存哈希、无法查看，只能重置**：设置页「重置管理员登录密码（立即生效）」／`docker exec -e MFA_RESET_PASSWORD='新密码' mail-archiver-fnos dotnet MailArchiver.dll --reset-password admin`／网关故障先 `--unbind admin`。

## ⚠️ 安全提示

- **安装日志含管理员口令（0.1.16 起已掩码），请勿截图外传**
- `@appconf/mail-archiver-fnos/` 下 `app.env`/`admin_password`/`pg_password`/`credential_encryption_key` 均为 **600 敏感文件**，备份按敏感件保管
- 能 `docker exec` 的人即可重置密码/解绑 ⇔ 等同数据库级权限，请限制宿主 SSH 与应用中心权限

## 已知限制

- **改数据目录不会搬数据**：切换后新目录是空库，原数据完整保留在 `.bak-<时间戳>`（详见 `docs/DATA-DIRECTION.md`）
- 应用日志看 `docker logs mail-archiver-fnos`（`@appdata/.../logs` 未使用；应用内「日志」页是访问审计）
- 同一 fnOS 账号被两人先后使用会继承会话（同一身份的必然结果）
- 后台服务异常被隔离（不拖死应用）但**不自愈**，需重启容器；巡检 `docker logs mail-archiver-fnos 2>&1 | grep -c "failed and will not continue"`

## 文档

- 完整安装说明：`docs/INSTALL-zh.md`
- 数据目录与卸载语义：`docs/DATA-DIRECTION.md`
- 排障：`docs/TROUBLESHOOTING.md`
- 版本对应表：`VERSION-MAP.md`
- 从源码复现本 fpk：`build/rebuild.sh`
- 第三方许可：`THIRD-PARTY-NOTICES`

## 许可

GPL-3.0（见 [LICENSE](LICENSE)）。本仓库是 [s1t5/mail-archiver](https://github.com/s1t5/mail-archiver) 的修改分发版（基线 `39f59d2`），修改见 [`patches/`](patches/)，同样以 GPL-3.0 分发。详见 [NOTICE](NOTICE)。
