#!/bin/bash
# 运行期目录的属主/权限权威实现 —— 由 install_callback / upgrade_callback / config_callback source。
# 与 app/docker/docker-compose.yaml 的挂载点一一对应（见 README「挂载点对照表」）。
#
# 为什么必须做：
#   容器以 ${TRIM_UID}:${TRIM_GID}（非 root）运行，而 bind mount 的宿主目录若属主是 root，
#   应用写不进去。最致命的是 DataProtection-Keys：写不了 keyring → 每次重启重新生成密钥 →
#   所有已登录会话失效（"重启即全员掉线"），首启还可能直接 500。
#   Docker 对"缺失的 bind 源目录"会自动建成 root:root 0755，所以必须显式核对。


# 允许被单独 source（测试/手工自检）：缺 say/fail 时给默认实现
command -v say >/dev/null 2>&1 || say() { echo "[mail-archiver-fnos] $*"; }
command -v fail >/dev/null 2>&1 || fail() { echo "[mail-archiver-fnos] ERROR: $*" >&2; exit 1; }

# 允许被单独 source：缺 VAR_DIR/DATA_ROOT 时按 TRIM_* 推导
VAR_DIR="${VAR_DIR:-${TRIM_PKGVAR:-}}"
DATA_ROOT="${DATA_ROOT:-${VAR_DIR}/data}"

# 目录清单：宿主路径|权限|是否强制mode|说明
# 注意：新增挂载点时必须同步这张表 + docker-compose.yaml + verify_runtime_dirs
runtime_dirs_spec() {
    cat <<SPEC
${VAR_DIR}|750|0|@appdata 根（挂载到容器 /data；平台创建，只校验属主，不改平台权限）
${VAR_DIR}/DataProtection-Keys|700|1|DP 密钥环（容器 /data/DataProtection-Keys，需读写+枚举）
${VAR_DIR}/logs|750|1|运行期日志（容器 /data/logs）
${VAR_DIR}/uploads|750|1|EML/MBox 导入暂存（容器 /app/uploads）
${VAR_DIR}/exports|750|1|审计/导出产物（容器 /app/exports）
${DATA_ROOT}|750|1|数据根（可能是指向存储空间的符号链接）
${DATA_ROOT}/mail|750|1|邮件原文/附件（容器 /mail）
${DATA_ROOT}/pgdata|700|1|PostgreSQL 数据（容器 /var/lib/postgresql/data，PG 要求 0700）
SPEC
}

# ---------------------------------------------------------------- 有效可写性探测（P0：看"能不能写"，不看"属主是谁"）
# 背景（用户实测）：先在「应用设置 → 访问权限」里**授权**了 /vol1/1000/mail-data，再把它设为数据目录，
# 仍被拒 —— 因为 ACL 授权 ≠ 属主变更，而旧实现只看 `stat -c %u == TRIM_UID`。
# 语义修正：**运行用户能真正写入就算通过**；属主不一致只记录（info），不再 fail。
_write_probe_name() { printf '%s/.write-probe.%s' "$1" "$$"; }

can_write_as_app() {   # 0=可写；1=不可写。**必须以"应用运行身份"能写为准**（root 能写不算）。
    [ -d "$1" ] || return 1
    local d="$1" probe; probe="$(_write_probe_name "${d}")"
    local me; me="$(id -u 2>/dev/null || echo '')"
    local sh_probe="touch '${probe}' && rm -f '${probe}'"

    # ① 我们现在就是应用身份：直接试写
    if [ "${me}" = "${TRIM_UID}" ]; then
        sh -c "${sh_probe}" 2>/dev/null && return 0 || return 1
    fi

    # ② 我们是 root：必须"降权到应用身份"试写，不能用 root 的 touch 冒充
    if [ "${me}" = "0" ]; then
        if command -v setpriv >/dev/null 2>&1 \
           && setpriv --reuid="${TRIM_UID}" --regid="${TRIM_GID}" --clear-groups sh -c "${sh_probe}" 2>/dev/null; then
            return 0
        fi
        if command -v runuser >/dev/null 2>&1 \
           && runuser -u "#${TRIM_UID}" -- sh -c "${sh_probe}" 2>/dev/null; then
            return 0
        fi
        if command -v sudo >/dev/null 2>&1 \
           && sudo -n -u "#${TRIM_UID}" -g "#${TRIM_GID}" sh -c "${sh_probe}" 2>/dev/null; then
            return 0
        fi
        # 容器内兜底（容器跑着时最权威）
        local app="${APP_NAME:-mail-archiver-fnos}" inside
        inside="$(mount_dest_for "${d}" 2>/dev/null)"
        if [ -n "${inside}" ] && command -v docker >/dev/null 2>&1 \
           && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${app}" \
           && docker exec -u "${TRIM_UID}:${TRIM_GID}" "${app}" sh -c "touch '${inside}/.write-probe' && rm -f '${inside}/.write-probe'" 2>/dev/null; then
            return 0
        fi
        return 1
    fi

    # ③ 其它身份：只能直接试写 + 容器内探测
    if sh -c "${sh_probe}" 2>/dev/null; then return 0; fi
    local app="${APP_NAME:-mail-archiver-fnos}" inside
    inside="$(mount_dest_for "${d}" 2>/dev/null)"
    if [ -n "${inside}" ] && command -v docker >/dev/null 2>&1 \
       && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${app}" \
       && docker exec -u "${TRIM_UID}:${TRIM_GID}" "${app}" sh -c "touch '${inside}/.write-probe' && rm -f '${inside}/.write-probe'" 2>/dev/null; then
        return 0
    fi
    return 1
}

# 宿主路径 → 容器内挂载点（仅本应用已知映射；未知返回空）
mount_dest_for() {
    case "$(readlink -f "$1" 2>/dev/null || echo "$1")" in
        "${TRIM_PKGVAR:-}") echo "/data" ;;
        "${DATA_ROOT:-}") echo "/data" ;;
        "${DATA_ROOT:-}"/mail) echo "/mail" ;;
    esac
}

# 可否安全"改属主"：仅当'我们就是属主或已是 root'时才直接 chown，否则不硬来
dir_owner() { stat -c '%u' "$1" 2>/dev/null || echo ''; }
dir_mode()  { stat -c '%a' "$1" 2>/dev/null || echo '?'; }

ensure_owned_dir() {
    _d="$1"; _mode="$2"; _enforce="${3:-1}"; _why="${4:-}"
    [ -n "${_d}" ] || return 0
    [ -L "${_d}" ] && _d="$(readlink -f "${_d}" 2>/dev/null || echo "${_d}")"
    if [ ! -d "${_d}" ]; then
        mkdir -p "${_d}" 2>/dev/null || fail "无法创建目录 ${_d}"
    fi
    _owner="$(dir_owner "${_d}")"

    # ① 先看"能不能写"：能写就通过（属主不一致只记录，不拦）
    if can_write_as_app "${_d}"; then
        if [ "${_owner}" != "${TRIM_UID}" ]; then
            say "属主为 UID ${_owner}（非 ${TRIM_UID}），但**运行用户可写入** → 按「可写」判定通过：${_d}"
        fi
        [ "${_enforce}" = "1" ] && { chmod "${_mode}" "${_d}" 2>/dev/null || true; }
        return 0
    fi

    # ② 不可写 → 尝试修属主：直接 chown → 免密 sudo chown -R → 再探测
    if chown "${TRIM_UID}:${TRIM_GID}" "${_d}" 2>/dev/null; then
        say "已修正属主：${_d} → ${TRIM_UID}:${TRIM_GID}"
    elif sudo -n chown -R "${TRIM_UID}:${TRIM_GID}" "${_d}" 2>/dev/null; then
        say "已用 sudo 修正属主：${_d} → ${TRIM_UID}:${TRIM_GID}"
    fi
    if can_write_as_app "${_d}"; then
        [ "${_enforce}" = "1" ] && { chmod "${_mode}" "${_d}" 2>/dev/null || true; }
        return 0
    fi

    # ③ 仍不可写 → 区分"数据目录根"与"pgdata"给出各自可执行出路
    _a="$(dir_mode "${_d}")"
    case "${_d}" in
        */pgdata)
            fail "PostgreSQL 数据目录不可用：${_d}
  当前属主: UID ${_owner}  当前权限: ${_a}  容器运行用户: ${TRIM_UID}:${TRIM_GID}
  PostgreSQL 对 pgdata 的属主/权限要求最严（必须属主 ${TRIM_UID}、mode 0700）。

请任选一种，然后重新安装/启动：
  A) 修属主与权限（首选）： sudo chown -R ${TRIM_UID}:${TRIM_GID} ${_d} && sudo chmod 700 ${_d}
  B) 换目录：安装向导里把数据目录选「默认」（应用自有目录），或换一个已授权给本应用的目录。"
            ;;
        *)
            fail "数据目录不可写：${_d}（${_why}）
  当前属主: UID ${_owner}（期望 ${TRIM_UID}）  当前权限: ${_a}  容器运行用户: ${TRIM_UID}:${TRIM_GID}
  **注意**：在「应用设置 → 访问权限」里的授权（ACL）**不会改变属主**；
  若你已授权过该目录，说明授权没有覆盖到**运行用户**（${TRIM_UID}:${TRIM_GID}），请按 A 执行或改用 B。

请任选一种后重新安装：
  提示：本存储卷的 ACL **可能不被强制**（实测 setfacl 后仍 denied），请优先用 A) 的 chown 方案。
  A) 一条命令修好（**首选**，直接改属主最稳）：
     sudo chown -R ${TRIM_UID}:${TRIM_GID} ${_d} && sudo chmod 755 ${_d}
     或（仅当确认该卷支持 ACL 时）：
     sudo setfacl -R -m u:${TRIM_UID}:rwx -m d:u:${TRIM_UID}:rwx ${_d}
  B) 换目录：安装向导里选「默认」（应用自有目录），或换一个已可写的存储空间目录。
  C) 放宽权限试试： sudo chmod 775 ${_d}"
            ;;
    esac
}

# 预建 + 修正属主（幂等：已正确则零变更）
ensure_runtime_dirs() {
    # 进程替换（不是管道）：同一 shell，ensure_owned_dir 里的 fail 才能真正终止调用方
    while IFS='|' read -r _p _m _enforce _why; do
        [ -n "${_p}" ] || continue
        ensure_owned_dir "${_p}" "${_m}" "${_enforce:-1}"
    done < <(runtime_dirs_spec)
    return 0
}

# 逐项校验（安装/升级末尾调用；任一不符 → 汇总报错并 exit 1）
verify_runtime_dirs() {
    _bad=0; _report=""
    while IFS='|' read -r _p _m _enforce _why; do
        [ -n "${_p}" ] || continue
        _real="${_p}"
        [ -L "${_real}" ] && _real="$(readlink -f "${_real}" 2>/dev/null || echo "${_real}")"
        if [ ! -d "${_real}" ]; then
            _report="${_report}
  ✗ ${_p} 不存在（期望权限 ${_m}；${_why}）"
            _bad=$((_bad + 1)); continue
        fi
        _ou="$(stat -c '%u' "${_real}" 2>/dev/null)"
        _a="$(stat -c '%a' "${_real}" 2>/dev/null)"
        _mode_bad=0
        [ "${_enforce:-1}" = "1" ] && [ "${_a}" != "${_m}" ] && _mode_bad=1
        _wok=0; can_write_as_app "${_real}" && _wok=1
        if [ "${_wok}" = "0" ]; then
            _report="${_report}
  ✗ ${_p}  **不可写**  实际 uid=${_ou} mode=${_a}（期望 uid=${TRIM_UID} mode=${_m}）  （${_why}）"
            _bad=$((_bad + 1))
        fi
    done <<EOF
$(runtime_dirs_spec)
EOF
    if [ "${_bad}" -ne 0 ]; then
        fail "运行期目录**可写性**校验未通过（${_bad} 项）：
${_report}

一键修复（以 root 执行）：
  chown -R ${TRIM_UID}:${TRIM_GID} ${VAR_DIR}
  chmod 700 ${VAR_DIR}/DataProtection-Keys
  chmod 750 ${VAR_DIR} ${VAR_DIR}/logs ${VAR_DIR}/uploads ${VAR_DIR}/exports ${DATA_ROOT} ${DATA_ROOT}/mail
  chmod 700 ${DATA_ROOT}/pgdata"
    fi
    say "运行期目录可写性校验通过（8 项；属主不一致但可写的项已按可写判定放行）"
    return 0
}

# ---------------------------------------------------------------- 载荷 docker 目录加固（0.1.21）
# ${TRIM_APPDEST}/docker/ 是平台按它起 compose 的地方，必须**始终**有这三样：
#   docker-compose.yaml(644) / app.env(600) / pg_password(600,非空,属主应用用户)。
# 之前只在 install 时写一次，切目录/失败回滚后可能缺失（已实测导致 compose 起不来）。
ensure_payload_docker_dir() {
    local app="${APP_NAME:-mail-archiver-fnos}"
    local dst="${APPDEST:-${TRIM_APPDEST}}/docker"
    local src="${APPCENTER:-/vol1/@appcenter/${app}}/docker"
    local need="" f
    mkdir -p "${dst}" 2>/dev/null || return 1
    if [ ! -f "${dst}/docker-compose.yaml" ] && [ -f "${src}/docker-compose.yaml" ]; then
        install -m 644 "${src}/docker-compose.yaml" "${dst}/docker-compose.yaml" 2>/dev/null && need="${need} docker-compose.yaml"
    fi
    if [ ! -s "${dst}/app.env" ] && [ -f "${src}/app.env" ]; then
        install -m 600 "${src}/app.env" "${dst}/app.env" 2>/dev/null && need="${need} app.env"
    fi
    if [ ! -s "${dst}/pg_password" ]; then
        if [ -s "${CFG_DIR:-${TRIM_PKGETC}}/pg_password" ]; then
            install -m 600 "${CFG_DIR:-${TRIM_PKGETC}}/pg_password" "${dst}/pg_password" 2>/dev/null && need="${need} pg_password"
        elif [ -s "${src}/pg_password" ]; then
            install -m 600 "${src}/pg_password" "${dst}/pg_password" 2>/dev/null && need="${need} pg_password"
        else
            (umask 077; LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 >"${dst}/pg_password") 2>/dev/null && need="${need} pg_password(新生成)"
        fi
    fi
    # 0.1.23：纠正 app.env 的 socket 落点（必须 @appcenter；旧版写 APPDEST 会绑定失败）
    _want="${APPCENTER:-/vol1/@appcenter/${app}}/app.sock"   # 0.1.26：实测绑 target 符号链接会 EADDRNOTAVAIL(99)，改绑其指向的真实路径（同一 inode）
    if [ -s "${dst}/app.env" ]; then
        _cur="$(grep -m1 '^LISTEN_UNIX_SOCKET=' "${dst}/app.env" 2>/dev/null | cut -d= -f2-)"
        if [ -n "${_cur}" ] && [ "${_cur}" != "${_want}" ]; then
            sed -i "s|^LISTEN_UNIX_SOCKET=.*|LISTEN_UNIX_SOCKET=${_want}|" "${dst}/app.env" 2>/dev/null || true
            sed -i "s|^ASPNETCORE_URLS=http://unix:.*|ASPNETCORE_URLS=http://unix:${_want}|" "${dst}/app.env" 2>/dev/null || true
            say "已纠正载荷 app.env 的 socket 落点：${_cur} → ${_want}"
            need="${need} app.env(socket修正)"
        fi
    fi
    for f in app.env pg_password; do
        [ -f "${dst}/${f}" ] && { chown "${TRIM_UID:-987}:${TRIM_GID:-982}" "${dst}/${f}" 2>/dev/null || true; chmod 600 "${dst}/${f}" 2>/dev/null || true; }
    done
    [ -f "${dst}/docker-compose.yaml" ] && chmod 644 "${dst}/docker-compose.yaml" 2>/dev/null || true
    if [ -n "${need}" ]; then say "已补齐载荷 docker 目录（${need# }）"; fi
    return 0
}
