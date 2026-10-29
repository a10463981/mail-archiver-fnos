#!/bin/bash
# 0.1.34 三个 Must-Fix 的落地片段（M1 share 分支 / M2 口令提示互斥 / M3 socket 假告警）
set -u

# ============ M1：B2「系统共享目录」分支落地 ============
# 把标准数据根链接到系统 share 目录，并在 share 里创建 mail/pgdata。
# 数据根可能是"已存在的链接"或"已存在的目录"，一律先清链接/空壳再建链接，目标绝不删。
apply_share_branch() {
    local share="${1-}" data_root="${2-}"
    if [ -z "$share" ] || [ "$share" = "none" ]; then
        echo "FATAL: B2 系统共享目录为空（TRIM_DATA_SHARE_PATHS 未给出 share），无法落地。"
        echo "       建议：回退默认目录并强 warn，而不是把数据写到不确定位置。"
        return 1
    fi
    mkdir -p "${share}/mail" "${share}/pgdata" 2>/dev/null || { echo "FATAL: 无法在 share 下创建 mail/pgdata: ${share}"; return 1; }

    # 数据根若是符号链接/目录/文件，都先仅删除"入口"本身，不动目标内容。
    if [ -L "$data_root" ] || [ -e "$data_root" ]; then
        rm -f "$data_root" 2>/dev/null
    fi
    ln -sfn "$share" "$data_root" 2>/dev/null || { echo "FATAL: 无法把数据根链接到 share: $data_root -> $share"; return 1; }

    echo "share 分支落地：${data_root} -> ${share}（mail/pgdata 已建在 share 里）"
    return 0
}

# 清理"B2 未落地时写错的默认目录记忆"：把 data_target 记忆文件指回 share。
clear_data_target_memory() {
    local memfile="$1" share="$2"
    [ -n "$memfile" ] || return 0
    if [ -n "$share" ] && [ "$share" != "none" ]; then
        printf '%s\n' "$share" > "$memfile" 2>/dev/null
        echo "已把 data_target 记忆纠正为 share：$share"
    else
        rm -f "$memfile" 2>/dev/null
        echo "已清空 data_target 记忆（share 为空，避免下次误恢复默认目录）"
    fi
}

# ============ M2：口令提示互斥（一个布尔量 + 两处 if）============
# has_users：库中是否已有账号（Users 表行数 > 0）。依据：pgdata 已 initdb 且 Users 表有行。
# 由 host 侧 docker exec … / psql 查询；此处提供统一判定入口。
DB_HAS_USERS=0
db_users_count_marker() { # 供 install_callback 用它自己的查询设置 DB_HAS_USERS
    local n="${1-0}"
    DB_HAS_USERS=$( [ "$n" -gt 0 ] && echo 1 || echo 0 )
}
print_account_origin() { # 互斥：有账号→沿用例；无账号→首次创建例。二者只打一条。
    if [ "$DB_HAS_USERS" = "1" ]; then
        echo "【沿用例】该库已有账号，本次向导里的管理员密码不生效，请用原密码登录。"
    else
        echo "【首次创建例】账号 admin 为首次创建，将使用本次配置的密码。"
    fi
}

# ============ M3：应用 socket 假告警降级 ============
# 轮询最多 timeout 秒；超时也只用 note，不以"失败"口吻收尾。
wait_for_app_socket() {
    local socket="$1" timeout="${2:-30}"
    local i=0
    while [ $i -lt "$timeout" ]; do
        [ -S "$socket" ] && { echo "应用 socket 已就绪：$socket"; return 0; }
        sleep 1; i=$((i+1))
    done
    echo "note: 应用仍在启动中（socket 尚未就绪，最多 ${timeout}s）；如持续请查 docker logs。"
    return 0   # 不 fail
}