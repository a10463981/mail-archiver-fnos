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

ensure_owned_dir() {
    _d="$1"; _mode="$2"; _enforce="${3:-1}"
    [ -n "${_d}" ] || return 0
    [ -L "${_d}" ] && _d="$(readlink -f "${_d}" 2>/dev/null || echo "${_d}")"
    if [ ! -d "${_d}" ]; then
        mkdir -p "${_d}" 2>/dev/null || fail "无法创建目录 ${_d}"
    fi
    _owner="$(stat -c '%u' "${_d}" 2>/dev/null || echo '')"
    if [ "${_owner}" != "${TRIM_UID}" ]; then
        if chown "${TRIM_UID}:${TRIM_GID}" "${_d}" 2>/dev/null; then
            say "已修正属主：${_d} → ${TRIM_UID}:${TRIM_GID}"
        else
            fail "目录 ${_d} 属主为 UID ${_owner}，不是 ${TRIM_UID}（容器运行用户），当前身份无权 chown。
以 root 执行后重试：
  chown -R ${TRIM_UID}:${TRIM_GID} ${_d}
原因：该目录被容器以非 root 身份 bind mount，属主不对会导致 DataProtection 密钥无法持久化（重启后全员掉线）或运行期写入失败。"
        fi
    fi
    [ "${_enforce}" = "1" ] && { chmod "${_mode}" "${_d}" 2>/dev/null || true; }
    return 0
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
        if [ "${_ou}" != "${TRIM_UID}" ] || [ "${_mode_bad}" = "1" ]; then
            _report="${_report}
  ✗ ${_p}  实际 uid=${_ou} mode=${_a}  期望 uid=${TRIM_UID} mode=${_m}$([ "${_enforce:-1}" = "1" ] || echo "（mode 不校验）")  （${_why}）"
            _bad=$((_bad + 1))
        fi
    done <<EOF
$(runtime_dirs_spec)
EOF
    if [ "${_bad}" -ne 0 ]; then
        fail "运行期目录属主/权限校验未通过（${_bad} 项）：
${_report}

一键修复（以 root 执行）：
  chown -R ${TRIM_UID}:${TRIM_GID} ${VAR_DIR}
  chmod 700 ${VAR_DIR}/DataProtection-Keys
  chmod 750 ${VAR_DIR} ${VAR_DIR}/logs ${VAR_DIR}/uploads ${VAR_DIR}/exports ${DATA_ROOT} ${DATA_ROOT}/mail
  chmod 700 ${DATA_ROOT}/pgdata"
    fi
    say "运行期目录属主/权限校验通过（8 项）"
    return 0
}
