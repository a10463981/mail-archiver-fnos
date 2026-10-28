#!/bin/bash
# 标准数据根删除/检测工具（供 cmd/uninstall_callback、cmd/install_callback 使用）
#
# 【重要设计约定 —— 2026-10-28 更正】
#   应用只管理**标准数据根** `${TRIM_PKGVAR}/data`。
#   · 它是**真实目录**  → 属于应用自己，delete 时 `rm -rf` 整个目录；
#   · 它是**符号链接**（用户把数据自定义到了存储空间，如 /vol1/1000/MailArchive）
#       → **只删链接本身，绝不对链接目标做任何删除/移动/改名**；并在日志里明确
#         "外部数据目录 <绝对路径> 保持不动，如需清理请自行处理"。
#   上一版曾"连目标一起删"，那会删掉用户自己的数据，**已彻底移除**。

purge_log() { printf '[purge] %s\n' "$*" >&2; }

# purge_standard_data_root <standard_root> [log_file]
#   返回 0 = 处理完成（真删 或 只删链接）；1 = 拒绝/失败（未动任何东西或已明确告知）
purge_standard_data_root() {
    local root="$1" log_file="${2:-}" real size

    [ -n "${root}" ] || { purge_log "missing data_root"; return 1; }

    # 白名单：只允许操作应用自己的标准数据根（${TRIM_PKGVAR} 之下，且层级足够）
    local var="${TRIM_PKGVAR:-}"
    # MF-5：变量为空时旧实现会退化成 `/data*` 之类宽匹配 —— 先判空，再要求**精确等于** ${var}/data。
    if [ -z "${var}" ]; then
        purge_log "拒绝：环境变量 TRIM_PKGVAR 为空，无法确认标准数据根，未做任何删除。"
        return 1
    fi
    if [ "${root}" != "${var}/data" ]; then
        purge_log "拒绝：${root} 不是应用标准数据根（应为 ${var}/data），未做任何删除。"
        return 1
    fi

    if [ -L "${root}" ]; then
        real="$(readlink -f "${root}" 2>/dev/null || true)"
        purge_log "标准数据根是符号链接：${root} -> ${real:-<无法解析>}"
        purge_log "外部数据目录 ${real:-?} **保持不动**（应用不管理该目录，删除数据时不会删除它；如需清理请自行处理）。"
        [ -n "${log_file}" ] && printf '%s [purge] keep-external %s (link %s removed)\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${real:-?}" "${root}" >>"${log_file}" 2>/dev/null
        rm -f "${root}" 2>/dev/null || true
        [ -L "${root}" ] && { purge_log "符号链接未删除干净：${root}"; return 1; }
        purge_log "已删除符号链接 ${root}（外部数据未动）"
        return 0
    fi

    if [ -d "${root}" ]; then
        size="$(du -sh "${root}" 2>/dev/null | awk '{print $1}')"
        purge_log "标准数据根是应用自有目录：将删除 ${root}（约 ${size:-未知}）"
        [ -n "${log_file}" ] && printf '%s [purge] delete-standard %s (%s)\n' \
            "$(date '+%Y-%m-%d %H:%M:%S')" "${root}" "${size:-?}" >>"${log_file}" 2>/dev/null
        rm -rf "${root}" 2>/dev/null || true
        [ -e "${root}" ] && { purge_log "删除失败（仍存在）：${root}"; return 1; }
        purge_log "已删除 ${root}"
        return 0
    fi

    purge_log "${root} 不存在，无需删除"
    return 0
}

# standard_root_has_db <standard_root>
#   0 = 标准数据根下已有非空 pgdata（若根是符号链接，只**读取**目标，不修改）
standard_root_has_db() {
    local root="$1" real
    [ -e "${root}" ] || [ -L "${root}" ] || return 1
    real="$(readlink -f "${root}" 2>/dev/null || true)"
    [ -n "${real}" ] && [ -d "${real}/pgdata" ] || return 1
    [ -n "$(ls -A "${real}/pgdata" 2>/dev/null)" ] || return 1
    return 0
}

# standard_root_is_external <standard_root>  → 0 表示标准数据根是符号链接（数据在外部）
standard_root_is_external() { [ -L "$1" ]; }
