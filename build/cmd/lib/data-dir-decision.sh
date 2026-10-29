#!/bin/bash
# 数据目录决策 M3 —— 显式优先级，供 install_callback source 后调用。
#
# decide_data_dir <wizard_dir> <share_dir> <existing_root> [log_fn]
#   输出最终决定并写入全局变量 DECIDED_DATA_DIR / DECIDED_BRANCH：
#     B1 用户指定目录（有库=沿用 / 空=初始化）
#     B2 系统共享目录
#     B3 保留现有数据根（share 为空、现有根有库）——绝不拿空库夺走已有库
#     B4 默认目录 + warn
set -u

# can_write_as_app <dir>  —— 降权到 987:982 真写一次
can_write_as_app() {
    local dir="$1"; [ -d "$dir" ] || return 1
    local probe="${dir}/.writable-probe.$$"
    if ! setpriv --reuid=987 --regid=982 --clear-groups sh -c "touch '$probe' && rm -f '$probe'" 2>/dev/null; then
        return 1
    fi
    return 0
}

# dir_has_db <root>  —— 该数据根下是否有 pgdata 且含真实数据库文件
dir_has_db() {
    local root="$1"
    [ -d "${root}/pgdata" ] || return 1
    # PG_VERSION 是建库后的必有文件，用它判定最稳
    [ -f "${root}/pgdata/PG_VERSION" ] && return 0
    return 1
}

decide_data_dir() {
    local wizard_dir="$1" share_dir="$2" existing_root="$3"
    DECIDED_BRANCH=""; DECIDED_DATA_DIR=""

    # ① 用户指定且可写 → 优先（三态在同一目录内区分沿用/初始化）
    if [ -n "$wizard_dir" ]; then
        if can_write_as_app "$wizard_dir"; then
            DECIDED_DATA_DIR="$wizard_dir"; DECIDED_BRANCH="B1 用户指定目录"
            if dir_has_db "$wizard_dir"; then
                echo "[decision] ① B1 用户指定目录（有库=沿用）: $wizard_dir"
            else
                echo "[decision] ① B1 用户指定目录（空=初始化）: $wizard_dir"
            fi
            return 0
        fi
        echo "[decision] warn: 用户目录不可写，放弃该目录: $wizard_dir"
    fi

    # ③ share 里无库 且 现有数据根有库 → 保留现有（不许空库夺走）
    if [ -n "$existing_root" ] && dir_has_db "$existing_root" \
       && { [ -z "$share_dir" ] || ! dir_has_db "$share_dir"; }; then
        DECIDED_DATA_DIR="$existing_root"; DECIDED_BRANCH="B3 保留现有数据根"
        echo "[decision] ③ B3 保留现有数据根（share 无库）: $existing_root"
        return 0
    fi

    # ② 未指定 → 系统共享目录
    if [ -z "$wizard_dir" ] && [ -n "$share_dir" ]; then
        DECIDED_DATA_DIR="$share_dir"; DECIDED_BRANCH="B2 系统共享目录"
        echo "[decision] ② B2 系统共享目录: $share_dir"
        return 0
    fi

    # ④ 兜底：默认目录 + warn
    DECIDED_DATA_DIR="${existing_root:-/vol1/@appdata/mail-archiver-fnos/data}"
    DECIDED_BRANCH="B4 默认目录(war)"; DECIDED_WARN=1
    echo "[decision] warn: ④ B4 回退默认目录: ${DECIDED_DATA_DIR}"
    return 0
}