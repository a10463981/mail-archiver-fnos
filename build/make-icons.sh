#!/bin/bash
# 由 512x512 源图生成 ICON.PNG(64) 与 ICON_256.PNG(256)（纯 Python，无 PIL 依赖）
python3 "$(dirname "$0")/png_resize.py" "$1" "$(dirname "$0")/ICON_256.PNG" 256
python3 "$(dirname "$0")/png_resize.py" "$1" "$(dirname "$0")/ICON.PNG" 64
