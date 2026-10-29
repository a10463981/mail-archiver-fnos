#!/bin/bash
# 从源码复现本 fpk 的镜像与安装包
#   用法： ./rebuild.sh <upstream-source-dir> <patch-series-dir> <out-dir>
# 前置： Docker、fnpack（fnOS 打包工具）、bash
set -euo pipefail
SRC="${1:?upstream source dir}"
PATCHES="${2:?patch series dir}"
OUT="${3:-$PWD/out}"
TAG="mail-archiver-fnos:zh-39f59d2-p30"
mkdir -p "$OUT"

echo "== 1) 应用补丁（按序号，基线 upstream commit 39f59d2）=="
git -C "$SRC" checkout -q 39f59d2
for p in $(ls "$PATCHES"/00*.patch | sort); do
  echo "   apply $(basename "$p")"
  git -C "$SRC" apply "$p"
done

echo "== 2) 构建镜像（tag 必须与 fpk 内 docker/image.ref 一致：$TAG）=="
docker build -t "$TAG" "$SRC"

echo "== 3) 导出镜像 tar（放进 fpk 的 app/images/）=="
docker save "$TAG" -o "$OUT/mail-archiver-fnos-zh-39f59d2-p30.tar"

echo "== 4) 组装 fpk 源目录 =="
#   build/cmd  build/config  build/wizard  build/app  build/ui  build/manifest  已在本仓库 build/ 下
#   app/images/*.tar 需放入上一步导出的 tar；随后 fnpack build
echo "   cp build/* → fpk 源目录，并把镜像 tar 放到 app/images/"
echo "   fnpack build"

echo "== 5) 校验（发布前三条自检）=="
echo "   a) md5sum app.tgz 必须等于 manifest.checksum"
echo "   b) app/images/*.tar 里 manifest.json 的 RepoTags 必须等于 docker/image.ref"
echo "   c) 安装用 env 文件的字段必须与 wizard/install 声明一致"
