# 版本映射表（Version Map）

## 一、当前版本

| 项 | 值 |
|---|---|
| 版本 | **`26.10.04`** |
| 上游基线 | `s1t5/mail-archiver` @ **`39f59d2`**（官方 `26.10.1`） |
| 应用镜像 | **`mail-archiver-fnos:zh-39f59d2-p33`**（已内嵌在 fpk 内） |
| 数据库镜像 | **`postgres:16-alpine`**（同样内嵌，安装全程离线） |
| 补丁 | **`0033-fnos-fpk-p7.net.patch`**（权威累积补丁） |
| 安装包 | `mail-archiver-fnos-26.10.04.fpk` |
| 大小 | **264,924,613 B** |
| sha256 | `7408988ec720fa315aec1624f3a5cc50fc163d764e415fe0fc43f7c4566c1995` |
| 下载 | https://github.com/a10463981/mail-archiver-fnos/releases/tag/26.10.04 |

### 已发布版本

| 版本 | 镜像 tag | 补丁 | 安装包大小 | sha256 |
|---|---|---|---|---|
| **`26.10.04`**（当前） | `zh-39f59d2-p33` | `0033` | 264,924,613 B | `7408988e…` |
| `26.10.01` | `zh-39f59d2-p30` | `0030` | 149,546,782 B | `969a54cd…` |

## 二、版本号规则

```
<上游发布线>.<我方发布序号>
  上游发布线 = 26.10   （上游 mail-archiver 官方发布线 26.10.x）
  发布序号   = 01      （首个正式发布；后续 02、03…）
```

本版镜像 tag：**`mail-archiver-fnos:zh-39f59d2-p30`**（完整值记录在 `build/app/docker/image.ref`）。

## 三、补丁索引

| 补丁 | 用途 | sha256 |
|---|---|---|
| **`0033-fnos-fpk-p7.net.patch`** | **当前权威累积补丁**（`26.10.04`）：旧 Cookie 解密失败改为清 Cookie + 302 登录页、全局解密兜底中间件、登录页「会话已过期」提示 | `66d90a76b6be5ca0993bb0e61c2765149f7eb2ba1cde153d183dc542fb9bec56` |
| `0032-fnos-fpk-p6.net.patch` | 上一版累积补丁（`26.10.03`，当前不使用） | `73bf7637ce1c24c0465a10e55eb79a9425a8080fa8ab45a65710a9ffe9f08730` |
| `0030-fnos-fpk-p4.net.patch` | 更早的累积补丁（`26.10.01`），仅留档 | `1d5b5db758d9e9dc1d140f1eb7f8bbba97bc0a422c3481fd645c541f6e3eae0f` |
| `0029-fnos-fpk-p3.27.patch` | 更早的累积补丁，仅留档 | `9748481fda5976b42a32e13dd4a62f383244889c5617bc5a1b4689dbada15896` |

复核：`cd patches && sha256sum -c SHA256SUMS`。

---

最后更新：**26.10.01**