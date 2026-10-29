# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver) 打包成 **飞牛 fnOS** 安装包。GPL-3.0，修改见 `patches/`。

## 最新版本：v0.1.22
见 [Releases](https://github.com/a10463981/mail-archiver-fnos/releases)（上游 `39f59d2`）。

**0.1.22**：**运行期不再支持切换数据目录**（设置页该项只读）。换目录请：应用中心「卸载」→ 选**保留数据** → 重新安装时在向导里指定新目录。同时修复 `ensure_payload_docker_dir` 调用顺序（此前导致载荷 `docker/` 缺失、容器起不来）。

## 如何更换数据目录
1. 应用中心 → 「邮件归档」→ 卸载 → 选 **保留数据**（个人目录不会被删除）
2. 应用中心 → 手动安装 → 选 `.fpk` → 向导里**指定新的数据目录**
3. 启动 → 用原账号密码登录

## 前置条件 / 文档 / 许可
fnOS ≥ 1.2.0401、x86_64、≥4GB。文档见 `docs/`；版本表 `VERSION-MAP.md`；GPL-3.0（[LICENSE](LICENSE)）。
