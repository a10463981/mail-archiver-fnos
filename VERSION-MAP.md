# 版本映射表（Version Map）

## 一、当前版本（唯一 Release）

| 项 | 值 |
|---|---|
| 版本 | **`26.10.01`（正式首发）** |
| 上游基线 | `s1t5/mail-archiver` @ **`39f59d2`**（官方 `26.10.1`） |
| 应用镜像 | **`mail-archiver-fnos:zh-39f59d2-p30`**（已内嵌在 fpk 内） |
| 补丁 | **`0030-fnos-fpk-p4.net.patch`**（权威累积补丁） |
| 安装包 | `mail-archiver-fnos-26.10.01.fpk` |
| 大小 | **149,546,782 B** |
| sha256 | `969a54cd6d815bed930db7a9b972646cf2df7560ab7637b50d3da6ab643dd0ad` |
| 下载 | https://github.com/a10463981/mail-archiver-fnos/releases/tag/26.10.01 |

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
| **`0030-fnos-fpk-p4.net.patch`** | **当前权威累积补丁**（`26.10.01`）：应用内忘记密码指引 + 网关 socket 加固修正 | `1d5b5db758d9e9dc1d140f1eb7f8bbba97bc0a422c3481fd645c541f6e3eae0f` |
| `0029-fnos-fpk-p3.27.patch` | 更早的累积补丁，**当前版本不使用**，仅随仓库留档 | `9748481fda5976b42a32e13dd4a62f383244889c5617bc5a1b4689dbada15896` |

复核：`cd patches && sha256sum -c SHA256SUMS`。

---

最后更新：**26.10.01**