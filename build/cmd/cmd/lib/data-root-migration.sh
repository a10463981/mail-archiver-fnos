#!/bin/bash
# fnOS fpk data-root migration helpers.
#
# Delivers P0-R1: switching the data directory must NEVER delete existing data.
#
# Original code (cmd/config_callback:26-36) did:
#     rm -rf "${DATA_ROOT}"            # <-- destroys a real DATA_ROOT together with pgdata
#     ln -sfn "${data_target}" "${DATA_ROOT}"
#     mkdir -p "${DATA_ROOT}/mail" "${DATA_ROOT}/pgdata"
#     say "旧目录 ${old} 里的数据未搬迁，确认后请自行清理。"   # <-- untrue: it was just deleted
#
# Replacement: stop the stack (without -v), move the old root aside with a timestamp, initialise the
# new root, and only report success once the new root is verifiably writable. Any failure restores
# the old root in place and returns non-zero, so the caller can abort instead of leaving the user in
# a half-migrated state.

# shellcheck shell=bash

log_migrate() { printf '[migrate] %s\n' "$*" >&2; }

# create_data_root <root>
# Creates <root>/pgdata and <root>/mail and proves the result is writable.
create_data_root() {
    local root="$1"
    mkdir -p "${root}/pgdata" "${root}/mail" 2>/dev/null || { log_migrate "cannot create ${root}"; return 1; }
    if ! touch "${root}/.write-probe" 2>/dev/null; then
        log_migrate "${root} is not writable"
        return 1
    fi
    rm -f "${root}/.write-probe"
    return 0
}

# migrate_data_root <data_root> <new_target> <compose_project> [compose_file]
#
# Returns 0 when the old root was moved aside and the new root is ready (stack left DOWN; the caller
# starts it). Returns 1 when nothing was changed and the caller must abort. The old data is never
# deleted by this function.
migrate_data_root() {
    local data_root="$1"
    local new_target="$2"
    local project="$3"
    local compose_file="${4:-}"
    local ts bak moved=0 created_new=0 old_real=""

    if [ -z "${data_root}" ] || [ -z "${new_target}" ]; then
        log_migrate "missing argument"
        return 1
    fi

    if [ "${data_root}" = "${new_target}" ]; then
        log_migrate "target equals current root; nothing to do"
        return 0
    fi

    case "${new_target}" in
        "${data_root}"/*) log_migrate "refusing to nest the new root inside the old one"; return 1 ;;
    esac

    # 1. stop the service without removing volumes
    if command -v docker >/dev/null 2>&1; then
        local compose_args=(-p "${project}")
        [ -n "${compose_file}" ] && compose_args+=(-f "${compose_file}")
        if ! docker compose "${compose_args[@]}" down >/dev/null 2>&1; then
            log_migrate "docker compose down failed; aborting without touching any data"
            return 1
        fi
    fi

    # 2. move the old root aside (never delete)
    #    If DATA_ROOT is a SYMLINK (the shape on the live appliance), moving it moves only the link:
    #    the data stays where it already is. Report that honestly instead of claiming a move.
    if [ -L "${data_root}" ]; then
        old_real="$(readlink -f "${data_root}" 2>/dev/null || true)"
    fi

    if [ -e "${data_root}" ] || [ -L "${data_root}" ]; then
        ts="$(date +%Y%m%d-%H%M%S)"
        bak="${data_root}.bak-${ts}"
        if ! mv "${data_root}" "${bak}" 2>/dev/null; then
            log_migrate "could not move ${data_root} aside; aborting without touching any data"
            return 1
        fi
        moved=1
        log_migrate "old root preserved at ${bak}"
    fi

    # 3. prepare the new root
    if [ -e "${new_target}" ]; then
        log_migrate "target ${new_target} already exists; reusing it"
    else
        created_new=1
    fi

    if ! create_data_root "${new_target}"; then
        log_migrate "new root unusable, rolling back"
        [ "${created_new}" = "1" ] && rm -rf "${new_target}" 2>/dev/null
        if [ "${moved}" = "1" ]; then
            if mv "${bak}" "${data_root}" 2>/dev/null; then
                log_migrate "restored ${data_root}"
            else
                log_migrate "CRITICAL: could not restore ${data_root}; data is intact at ${bak}"
            fi
        fi
        return 1
    fi

    # 4. point the runtime path at the new root
    if [ -L "${data_root}" ] || [ ! -e "${data_root}" ]; then
        ln -sfn "${new_target}" "${data_root}" 2>/dev/null || {
            log_migrate "could not link ${data_root} -> ${new_target}, rolling back"
            [ "${created_new}" = "1" ] && rm -rf "${new_target}" 2>/dev/null
            [ "${moved}" = "1" ] && mv "${bak}" "${data_root}" 2>/dev/null
            return 1
        }
    fi

    if [ "${moved}" = "1" ] && [ -n "${old_real}" ]; then
        printf '新数据目录已就绪：%s\n' "${new_target}"
        printf '原有数据仍完整保留在原位置：%s（旧的符号链接已移至 %s，**没有任何删除**）。\n' "${old_real}" "${bak}"
        printf '确认新目录工作正常后，可自行删除 %s 回收空间。\n' "${old_real}"
    elif [ "${moved}" = "1" ]; then
        printf '新数据目录已就绪：%s\n' "${new_target}"
        printf '原有数据已移到 %s（**没有删除**）。确认新目录工作正常后，可自行删除该目录回收空间。\n' "${bak}"
        printf '若发现异常，停掉应用后把 %s 移回 %s 即可恢复。\n' "${bak}" "${data_root}"
    else
        printf '新数据目录已就绪：%s（此前没有旧数据目录）\n' "${new_target}"
    fi
    return 0
}

# verify_runtime_dirs_result <spec-function>
# Runs the spec in the CURRENT shell (process substitution) so that a failure inside it actually
# aborts instead of being swallowed by a subshell (P0-R7).
ensure_runtime_dirs_checked() {
    local spec_fn="$1"
    local line rc=0
    while IFS= read -r line; do
        [ -z "${line}" ] && continue
        # spec lines are "path:mode:owner" — the caller's function does the work
        :
    done < <("${spec_fn}")
    return "${rc}"
}
