# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver) 打包成 **飞牛 fnOS** 安装包（`.fpk`）。

> ⚠️ 本仓库是上游的**修改分发版**，修改见 `patches/`，同样以 **GPL-3.0** 分发。

## 最新版本：v0.1.21

见 [Releases](https://github.com/a10463981/mail-archiver-fnos/releases)（上游 `39f59d2`）。

**0.1.21**：切数据目录前**无条件对齐数据库口令**（修复切到已有库时因口令不一致导致应用起不来）；每次启动自动补齐载荷 `docker/` 目录（`app.env`/`pg_password`/`compose`）。含 0.1.20 及之前全部修复。

## 前置条件
fnOS ≥ 1.2.0401、x86_64、内存 ≥4GB。

## 安装/卸载/密码语义/安全
见 `docs/` 与 `VERSION-MAP.md`。

## 许可
GPL-3.0（[LICENSE](LICENSE)）。上游 [s1t5/mail-archiver](https://github.com/s1t5/mail-archiver)（`39f59d2`）的修改分发版。
