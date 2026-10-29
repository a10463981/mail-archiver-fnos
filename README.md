# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver) 打包成 **飞牛 fnOS** 安装包。GPL-3.0，修改见 `patches/`。

## 最新版本：v0.1.23
见 [Releases](https://github.com/a10463981/mail-archiver-fnos/releases)（上游 `39f59d2`）。

**0.1.23**：socket 落点统一为 `/vol1/@appcenter/<app>/app.sock`（修"应用起不来/网关 502"）；安装期数据目录校验改为"以运行用户 987 真实试写"（root 不再误判可写）；数据目录选择给出三步指引。
**0.1.22**：运行期不再支持切换数据目录。

## 📁 数据目录怎么选才会成功
**首次安装时应用还不存在**，无法预先在「应用设置 → 访问权限」里授权目录。所以：
1. 先用**默认目录**装一次
2. 装好后：应用设置 → 访问权限 → 授权你的目录
3. 卸载（选**保留数据**）→ 重装时在向导里指定该目录

技术替代（root）：`sudo chown -R 987:982 <目录> && sudo chmod 755 <目录>`（本卷 ACL 可能不生效，优先 chown）。

## 前置条件 / 文档 / 许可
fnOS ≥ 1.2.0401、x86_64、≥4GB。文档 `docs/`；版本表 `VERSION-MAP.md`；GPL-3.0（[LICENSE](LICENSE)）。
