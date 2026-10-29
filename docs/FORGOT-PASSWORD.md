# 🔑 忘记密码 / 登录不上怎么办

**按顺序试，第 1 条是首选（最安全、立即生效）：**

1. **应用中心 →「邮件归档」→ 应用设置 → 运行设置 → 管理员登录密码** → 填新密码 → 保存。
   保存后**立即生效**（旧密码当场失效），应用内账号（默认 `admin`）即可用新密码登录。
   > 密码只以哈希形式保存，**无法查看**，只能重置。

2. **应用界面进不去、但容器还在跑**时，可用包内 CLI 直接重置：
   ```bash
   docker exec -e MFA_RESET_PASSWORD='你的新密码' mail-archiver-fnos \
     dotnet MailArchiver.dll --reset-password admin
   ```
   账号名以 `app.env` 里的 `Authentication__Username` 为准（通常就是 `admin`）。

3. **网关绑定异常导致始终进不去**时，先解绑再用密码登录，成功后可重新绑定：
   ```bash
   docker exec mail-archiver-fnos dotnet MailArchiver.dll --unbind admin
   ```

4. **两个口令不是一回事，别混**：
   - **管理员登录密码** = 网页/桌面登录用（第 1 条重置的就是它）；
   - **数据库口令** = 应用连 PostgreSQL 内部用，与登录无关。
     查看数据库口令明文用 `--show-db-password`（它**不是**登录密码）；只看指纹用 `--show-db-fingerprint`。

> 小提示：忘记密码不会导致数据丢失——账号与邮件都在库里，重置密码只是换掉登录凭据。

---

最后更新：**26.10.01**
