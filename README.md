# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver) 打包成 **飞牛 fnOS** 安装包（`.fpk`）。

> ⚠️ 本仓库是上游的**修改分发版**，修改见 `patches/`，同样以 **GPL-3.0** 分发。

## 最新版本：v0.1.20

见 [Releases](https://github.com/a10463981/mail-archiver-fnos/releases)（上游 `39f59d2`）。

**0.1.20**：卸载「删除数据」= 真干净（清掉"记住的数据目录"，重装回默认数据根）；失效目录记忆自动忽略。含 0.1.19 全部修复（切目录 `--force-recreate`、失败保可用、渲染修属主、补 compose、socket 挂载、`.bak` 唯一化、看护 90s、28P01 自愈、空目录不算残留）。

## 前置条件
fnOS ≥ 1.2.0401、x86_64、内存 ≥4GB。

## 安装 / 卸载 / 密码语义 / 安全
见 `docs/` 与 `VERSION-MAP.md`。

## 许可
GPL-3.0（[LICENSE](LICENSE)）。上游 [s1t5/mail-archiver](https://github.com/s1t5/mail-archiver)（`39f59d2`）的修改分发版。
