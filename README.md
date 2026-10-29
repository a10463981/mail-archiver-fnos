# Mail-archiver for fnOS（mail-archiver-fnos）

把 [Mail-archiver](https://github.com/s1t5/mail-archiver) 打包成 **飞牛 fnOS** 安装包。GPL-3.0，修改见 `patches/`。

## 最新版本：v0.1.25

**0.1.25（重要架构调整，对齐官方范式）**
- **数据目录改用官方 `data-share`**：`config/resource` 声明 `mail-archiver/data`，安装时飞牛**自动创建目录并自动把 ACL 授予应用用户** → **不再需要**「应用设置 → 访问权限」授权、**不再需要**二次重装、也不需要手动 `chown`。数据根优先取 `TRIM_DATA_SHARE_PATHS`。
- **socket 落点改回官方规范**：网关转发目标固定 `/var/apps/<app>/target/app.sock`（`target` 是平台符号链接 → `@appcenter/<app>`）。容器内 `LISTEN_UNIX_SOCKET=/var/apps/<app>/target/app.sock`。**这是此前"页面 404"的最可能原因**（旧版把 socket 放在非 target 路径）。
- `manifest` 增加 `disable_authorization_path=true`（设置页不再出现目录授权项）。
- 向导里不再让用户填路径（数据目录由系统分配）。
- 卸载：**共享目录（data-share）一律不删除**（keep / delete 都不删），日志提示位置。

## 安装即用
1. 应用中心 → 手动安装 → 选 `.fpk`
2. 向导填管理员账号/密码/时区 → 完成 → 启动
3. 桌面点开即可（数据在系统分配的共享目录里，无需授权）

想换位置或重置：**卸载（保留数据）后重装**。共享目录不会被删除。

## 前置条件 / 文档 / 许可
fnOS ≥ 1.2.0401、x86_64、≥4GB。文档 `docs/`；版本表 `VERSION-MAP.md`；GPL-3.0（[LICENSE](LICENSE)）。
