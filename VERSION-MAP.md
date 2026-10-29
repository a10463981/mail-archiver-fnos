# 版本对应表

镜像 tag 前缀固定为 **`mail-archiver-fnos:zh-39f59d2`**（`39f59d2` = 上游基线 commit）；实际写入 fpk 的完整 tag 见 `build/app/docker/image.ref`（当前记录 `mail-archiver-fnos:zh-39f59d2-p30`，早期版本无 `-pNN` 后缀）。

补丁序号对应 `patches/` 下的权威累积补丁；**`0029-fnos-fpk-p3.27.patch` 为当前权威补丁**（sha256 `9748481fda5976b42a32e13dd4a62f383244889c5617bc5a1b4689dbada15896`，见 `patches/SHA256SUMS`）。

## 已公开发布的版本（Release 资产）

下表 size / sha256 均为**各 Release 的 `SHA256SUM.txt` 中登记值**（可用 `sha256sum -c` 复核）。

| fpk | 补丁 | 要点 | size (B) | sha256 | 状态 |
|---|---|---|---|---|---|
| 0.1.16 | 0029 | 首个公开发布版；发布前 6 条修复（MF-1…MF-6：改目录提示/日志只对新库打印密码/掩码/单次重置/白名单精确匹配/purge 缺失即中止） | 149,511,583 | `15d7e21f362d002b08ccc02715504101581b8b20dac7c10a2403a6819f79ca71` | 历史 |
| 0.1.18 | 0029 | 数据目录切换加固（90s 保护、socket 挂载、compose 渲染、唯一 `.bak`、自愈） | 149,511,157 | `61e816ca7bfb62bca4eccb85efd006c4b676b85a815dc8969e98f524134391a2` | 勿用（缺 force-recreate） |
| 0.1.19 | 0029 | `config_callback` 加 `--force-recreate` | 149,508,944 | `0b5e3e14f7ee4f03e4751a0f9743ba946aef92b3424df4a27f2125cd7d7531e1` | 历史 |
| 0.1.20 | 0029 | 卸载「删除数据」同步清除 `data_target` | 149,511,309 | `bf66078a0d0c4a478d2fbceef6b5fe0caf14670058ee1adf72f0deb3f3a64eee` | 历史 |
| 0.1.21 | 0029 | 切库对齐数据库口令；每次启动确保 payload docker 目录 | 149,510,250 | `26cea81f65d5ac812921ea29e2aea49868a9981f50dce79b942c6584d3fe6ec5` | 历史 |
| 0.1.22 | 0029 | **移除运行期切换数据目录**（方案 B） | 149,510,579 | `06e31a6c5ef7be595646ca1fb9dffaa64759dca3027938769fde26b01076f95d` | 历史 |
| 0.1.23 | 0029 | 统一 socket 落点为 `@appcenter/<app>/app.sock`；安装期可写校验降权到运行用户 | 149,509,589 | `027c1cc23ad39f17b0fd4f5861ddcceb9384b822cfc667bcb2014810cc10c8b6` | 历史 |
| 0.1.24 | 0029 | 安装期三态数据目录决策 | 149,511,866 | `fee4186dc8c592e6771eeb0dc962a79cefd3e620aada3f95ecaa498eefe1c42f` | 历史 |
| 0.1.25 | 0029 | **改用官方 `data-share` 范式**（系统自动建目录 + 自动 ACL）；socket 落点改 `target/app.sock` | 149,515,299 | `06f310af4ac94c9876b2930766730b7ad85fb85aa2cb1690999f344c4fd1e6c2` | 历史 |
| 0.1.26 | 0029 | 修 socket `EADDRNOTAVAIL`（经 target 符号链接）；内容级残留判定；共享目录 vs 已有库优先级 | 149,518,794 | `67a16da406445e3cc756f97852336d3761500fa77d0275eb01e530d79d0ffecd` | 可用 |
| 0.1.27 | 0029 | 空壳判定与口令自检 | 149,514,540 | `8981d07febbd4e38c180a23ece72cef46d379e5db20fcc4bf5147bad09803624` | 可用 |
| **0.1.28** | **0029** | 数据目录可选 + 口令自检修正 | 149,520,089 | `9cc233305aa5b1e5446a54f9089ee11c020069cc9ac3a60424cf0a3c5f4ad0b2` | **当前最新** |

## 未公开发布的版本

| 范围 | 说明 |
|---|---|
| 0.1.4 – 0.1.15 | 本地历史构建，**未发布为 Release，无公开资产与公开校验值**，故本表不列 sha256（不臆造）。其中 0.1.11 / 0.1.12 / 0.1.13-BADTAG 明确作废，见 `docs/KNOWN-ISSUES.md`。 |
| 0.1.17 | 无对应构建 |

## 复核方式

```bash
# 下载对应版本的 SHA256SUM.txt 与 fpk 后
sha256sum -c SHA256SUM.txt
```

补丁完整性：`cd patches && sha256sum -c SHA256SUMS`。