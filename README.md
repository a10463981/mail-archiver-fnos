# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver)（.NET 邮件归档与检索服务）打包成 **飞牛 fnOS** 安装包（`.fpk`）。

> ⚠️ 本仓库是上游的**修改分发版**，修改见 `patches/`，同样以 **GPL-3.0** 分发。详见 [NOTICE](NOTICE) 与 [LICENSE](LICENSE)。

## 最新版本

**v0.1.19**（上游 commit `39f59d2`）—— 见 [Releases](https://github.com/a10463981/mail-archiver-fnos/releases)。
> 0.1.18 包内缺 `--force-recreate`（切数据目录仍会连旧库），**请用 0.1.19**。

**0.1.19 修复**：数据目录切换强制重建容器（切目录后数据库真正跟着切换）、失败保可用、渲染修属主、补 compose、socket 目录挂载、`.bak` 唯一化、看护 90s、`28P01` 自动对齐、空目录不算残留。

## 前置条件
fnOS ≥ 1.2.0401（实测 1.2.0800）、x86_64、内存建议 ≥4GB。

## 安装（从 Releases 下载）
1. 下载 `mail-archiver-fnos-0.1.19.fpk` 与 `SHA256SUM.txt`
2. `shasum -a 256 mail-archiver-fnos-0.1.19.fpk` 比对
3. 应用中心 → 手动安装 → 选 `.fpk`（向导密码仅首次建库生效；**首登强制改密属正常**）
4. 数据目录建议放存储空间；装完启动 → 桌面图标打开

## 卸载与数据
「保留数据」沿用旧账号（升级选这个）；「删除数据」只删应用自有目录，若数据目录是指向存储空间的**符号链接**则**只删链接**。

## 🔑 密码语义
全新库=向导密码（首登改密）；保留数据重装=原密码；**只存哈希、无法查看、只能重置**。

## ⚠️ 安全提示
安装日志含口令（已掩码）勿外传；`@appconf` 下文件 600 敏感件；能 `docker exec` = 库级权限。

## 文档
安装 `docs/INSTALL-zh.md`；数据目录语义 `docs/DATA-DIRECTION.md`；切换排障 `docs/DATA-DIR-SWITCH.md`；排障 `docs/TROUBLESHOOTING.md`；版本表 `VERSION-MAP.md`；复现构建 `build/rebuild.sh`。

## 许可
GPL-3.0（[LICENSE](LICENSE)）。上游 [s1t5/mail-archiver](https://github.com/s1t5/mail-archiver)（`39f59d2`）的修改分发版。
