#!/bin/bash
# 数据根「删除」与「防线判定」—— 卸载(删除数据)只删链接不碰目标；安装防线按三态区分，不自相矛盾。
set -u

# ---- 卸载(删除数据)：删标准数据根，链接只删自己、绝不动目标 ----
purge_standard_data_root() {
    local root="${1:-${TRIM_PKGVAR}/data}"
    if [ -L "$root" ]; then
        local real; real=$(readlink -f "$root" 2>/dev/null || readlink "$root" || echo "(未知)")
        if rm -f "$root" 2>/dev/null; then
            echo "已删除符号链接 ${root}（目标 ${real} 保持不动，未删除）"
        else
            echo "FAIL: 无法删除符号链接 ${root}"; return 1
        fi
    elif [ -d "$root" ]; then
        if rm -rf "$root" 2>/dev/null; then
            echo "已删除数据目录 ${root}（应用自有）"
        else
            echo "FAIL: 删除 ${root} 失败"; return 1
        fi
    else
        echo "note: ${root} 不存在，无需删除"
    fi

    # 删除后必须不存在（含断链）
    if [ -e "$root" ] || [ -L "$root" ]; then
        echo "FAIL: ${root} 删除后仍存在"; return 1
    fi
    return 0
}

# ---- 判定数据根里是否真有数据（非空 pgdata）----
dir_has_nonempty_pgdata() {
    local root="$1"
    [ -d "${root}/pgdata" ] || return 1
    [ -n "$(find "${root}/pgdata" -mindepth 1 -print -quit 2>/dev/null)" ] || return 1
    return 0
}

# ---- 安装防线：区分 share 链接 / 用户链接 / 真实目录含数据 ----
# 参数： root(标准数据根)  last_action(keep|delete)
# 返回： 0=放行  1=fail（真"没删干净"才拦）
data_root_defense_line() {
    local root="$1" last_action="${2:-keep}"

    if [ -L "$root" ]; then
        local real; real=$(readlink -f "$root" 2>/dev/null || readlink "$root" || echo "")
        case "$real" in
            *appshare*|*data-share*|*/share|*/share/*)
                echo "note: 数据根是指向系统共享目录的链接（${real}），属正常 share 模式，放行。"
                return 0 ;;
            /vol1/*)
                echo "note: 数据根是指向用户自建目录的链接：${real}，保留并放行。"
                return 0 ;;
            *)
                echo "note: 数据根是符号链接 ${root} -> ${real}，放行（不删目标）。"
                return 0 ;;
        esac
    fi

    if [ -d "$root" ]; then
        if [ "$last_action" = "delete" ] && dir_has_nonempty_pgdata "$root"; then
            echo "FAIL: 上次卸载选择「删除数据」，但数据根仍存在且含数据，安装中止。"
            echo "      请删除：${root}"
            return 1
        fi
        echo "note: 数据根存在（${last_action} 模式），放行，交给三态判断。"
        return 0
    fi

    echo "note: 数据根不存在，视为全新安装。"
    return 0
}