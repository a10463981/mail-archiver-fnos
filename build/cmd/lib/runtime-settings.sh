#!/bin/bash
# 运行设置（config_callback）动作分派：数据库口令修改 + 管理员密码重置。
# 可测：PSQL_CMD / CLI_CMD / RESTART_CMD / READY_CHECK 可被外部桩覆盖；明文只经环境变量，不进 argv。
set -u

PSQL_CMD="${PSQL_CMD:-psql}"
DB_BIN="${DB_BIN:-docker}"
DB_SUB="${DB_SUB:-exec}"
DB_CONTAINER="${DB_CONTAINER:-mail-archiver-fnos-db}"
DB_USER="${DB_USER:-mailarchiver}"          # 数据库角色名（ALTER 用）
APP_USER="${APP_USER:-admin}"               # 应用账号名（重置用，来自 app.env Authentication__Username）
TCP_VERIFY_HOST="${TCP_VERIFY_HOST:-postgres}"
APP_NAME="${APP_NAME:-mail-archiver-fnos}"
RESTART_CMD="${RESTART_CMD:-:}"
READY_CHECK="${READY_CHECK:-:}"

# 校验：库口令非空时 ≥16 且非占位；管理密码非空时 ≥8。
runtime_settings_validate() { # db_pw admin_pw  -> 0 ok / 1 fail
    local dbp="${1-}" admp="${2-}"
    if [ -n "$dbp" ]; then
        if ! pg_password_is_valid "$dbp"; then
            echo "REJECT: 数据库口令须 ≥16 位且非占位符（change_me 等）。" >&2; return 1
        fi
    fi
    if [ -n "$admp" ]; then
        [ "${#admp}" -ge 8 ] || { echo "REJECT: 管理员密码须 ≥8 位。" >&2; return 1; }
    fi
    return 0
}

# ALTER ROLE 改库口令（容器内 trust + 容器内 TCP 验证；明文只进环境变量）
alter_role_password() { # host user db new  -> 0/1
    local host="$1" user="$2" db="$3" new="$4" esc out rc out2 rc2
    esc=$(printf '%s' "$new" | sed "s/'/''/g")
    out=$("$DB_BIN" "$DB_SUB" "$DB_CONTAINER" psql -U "$user" -d "$db" -v ON_ERROR_STOP=1 \
        -c "ALTER ROLE \"${user}\" WITH PASSWORD '${esc}'" 2>&1); rc=$?
    [ $rc -ne 0 ] && { echo "ALTER 失败：${out}" >&2; return 1; }
    out2=$("$DB_BIN" "$DB_SUB" -e PGPASSWORD="$new" "$DB_CONTAINER" psql -h "$TCP_VERIFY_HOST" -U "$user" -d "$db" -tAc 'select 1' 2>&1); rc2=$?
    [ $rc2 -ne 0 ] && { echo "ALTER 验证失败：${out2}" >&2; return 1; }
    echo "ALTER ROLE 完成（指纹 $(db_fingerprint "$new")）"
    return 0
}

# 管理密码重置：容器内执行应用 CLI，密码只走 MFA_RESET_PASSWORD 环境变量，绝不在 argv。
# user = 应用账号（admin），不是数据库角色（mailarchiver）。
reset_admin_password_via_cli() { # user new  -> 0/1
    local user="$1" new="$2" out rc
    out=$("$DB_BIN" "$DB_SUB" -e MFA_RESET_PASSWORD="$new" "$APP_NAME" dotnet MailArchiver.dll --reset-password "$user" 2>&1); rc=$?
    if [ $rc -ne 0 ]; then
        echo "CLI 重置失败：${out}" >&2
        echo "  若报 no account named X：说明应用账号名传错。本应用账号通常为 admin（见 app.env 的 Authentication__Username）。" >&2
        local act
        act=$("$DB_BIN" "$DB_SUB" "$DB_CONTAINER" psql -U "$DB_USER" -d "mailarchiver" -tAc 'select string_agg("Username",'"'"', '"'"') from mail_archiver."Users"' 2>/dev/null)
        [ -n "$act" ] && echo "  库里实际账号：${act}" >&2
        return 1
    fi
    echo "管理员密码已重置（${user}）——保存后应用会重启约 10 秒。"
    return 0
}

# 校验并收集**所有**错误（不遇错即停），返回非 0 若任一非法。
runtime_settings_collect_errors() { # db_pw admin_pw
    local dbp="${1-}" admp="${2-}" n=0
    if [ -n "$dbp" ] && ! pg_password_is_valid "$dbp"; then
        echo " - 数据库口令须 ≥16 位且非占位符（change_me 等）"
        n=1
    fi
    if [ -n "$admp" ] && [ "${#admp}" -lt 8 ]; then
        echo " - 管理员登录密码须 ≥8 位"
        n=1
    fi
    return $n
}

# 主分派：各自校验 → 合法的执行、非法的报错（互不阻塞）→ 有改动才重启一次。
# 参数：db_pw admin_pw host user db file_list backup_dir
runtime_settings_apply() {
    # 参数：dbp admp app_user(=user) host db files bdir；ALTER 用 DB_USER，重置用 app_user。
    local dbp="${1-}" admp="${2-}" host="$3" user="$4" db="$5" files="${6-}" bdir="${7-}"
    local did=0 db_ok=0 ad_ok=0

    [ -n "$dbp" ] && pg_password_is_valid "$dbp" && db_ok=1
    [ -n "$admp" ] && [ "${#admp}" -ge 8 ] && ad_ok=1

    if [ -n "$dbp" ] && [ "$db_ok" = "0" ]; then echo "错误：数据库口令须 ≥16 位且非占位符。" >&2; fi
    if [ -n "$admp" ] && [ "$ad_ok" = "0" ]; then echo "错误：管理员登录密码须 ≥8 位。" >&2; fi

    # 备份
    local ts; ts=$(date +%Y%m%d-%H%M%S)
    [ -n "$bdir" ] && mkdir -p "$bdir"
    local f
    while IFS= read -r f; do
        [ -n "$f" ] && [ -e "$f" ] && cp -a "$f" "${f}.bak-${ts}" 2>/dev/null
    done <<EOF
$files
EOF

    # 两个动作独立执行，互不阻塞
    if [ "$db_ok" = "1" ]; then
        if alter_role_password "$host" "$DB_USER" "$db" "$dbp"; then
            echo "[结果] 数据库口令：已修改。"; did=1
        else
            echo "[结果] 数据库口令：修改失败（原值不变，见上方原因）。" >&2
        fi
    fi

    if [ "$ad_ok" = "1" ]; then
        if reset_admin_password_via_cli "$user" "$admp"; then
            echo "[结果] 管理员登录密码：已重置（立即生效）。"; did=1
        else
            echo "[结果] 管理员登录密码：重置失败（可用 CLI 兜底）。" >&2
        fi
    fi

    if [ "$did" = "1" ]; then
        echo "配置已改动；重启应用（约 10 秒）。"
        $RESTART_CMD
        local i=0
        while [ $i -lt 30 ]; do
            if $READY_CHECK; then echo "应用已就绪。"; return 0; fi
            sleep 1; i=$((i+1))
        done
        echo "note: 应用仍在启动中（最多 30s）；如持续请查 docker logs。" >&2
    else
        echo "无改动，不重启。"
    fi
    return 0
}