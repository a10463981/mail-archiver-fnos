#!/bin/bash
# can_write_as_app <dir> <uid> <gid>   -> 0 可写，非 0 不可写。
# 用于「数据目录（可选）」字段的校验：填了就必须对应用运行用户可写，否则沿用已有库会写不进。
can_write_as_app() {
    local dir="$1" uid="${2:-987}" gid="${3:-982}"
    [ -d "$dir" ] || { echo "目录不存在"; return 1; }
    # 取目录属主
    local ouid ogid
    ouid=$(stat -c '%u' "$dir" 2>/dev/null)
    ogid=$(stat -c '%g' "$dir" 2>/dev/null)
    # 属主是应用用户，或组是应用组且组有写位
    if [ "$ouid" = "$uid" ] || { [ "$ogid" = "$gid" ] && [ $(( $(stat -c '%a' "$dir" | tail -c2) & 2 )) -ne 0 ]; }; then
        return 0
    fi
    # 其它用户可写也行（宽松）
    local mode; mode=$(stat -c '%a' "$dir")
    [ $(( mode & 2 )) -ne 0 ] && return 0
    echo "目录 $dir 对 $uid:$gid 不可写"
    return 1
}
