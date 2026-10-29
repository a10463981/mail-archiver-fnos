#!/bin/bash
# pg_password 写入守卫 —— 杜绝占位符/弱值写进口令文件。
#
# 真机证据：@appconf/pg_password = 9 字节 "change_me"（占位符），而真口令 32 字节在 .appstate 与连接串里。
# 结论：某个"回填/写入"路径用错了值来源，把占位符当口令写了进去。
set -u

# 是否像占位符（change_me / CHANGE_ME / 空 / 纯空白）
looks_like_placeholder() {
    local v
    v=$(printf '%s' "$1" | tr -d '[:space:]')
    [ -z "$v" ] && return 0
    case "$v" in
        change_me|change_me_*|changeme|changeme_*|CHANGE_ME|CHANGE_ME_*|CHANGEME|CHANGEME_*|changeme_please|please_change_me) return 0 ;;
    esac
    return 1
}

# 口令是否合规：非占位符 && 长度 >= 16
pg_password_is_valid() {
    local v="${1-}"
    looks_like_placeholder "$v" && return 1
    v=$(printf '%s' "$v" | tr -d '\r\n')
    [ "${#v}" -ge 16 ] || return 1
    return 0
}

# 原始生成器（内部用）。公开的 generate_pg_password 在"沿用库"模式下会拒绝。
_gen_pg_password_raw() {
    local a b
    a=$(openssl rand -hex 16 2>/dev/null || { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; })
    b=$(openssl rand -hex 16 2>/dev/null || { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; })
    printf '%s%s' "$a" "$b"
}

# 是否处于"沿用已有库"路径。此时禁止重新生成新口令（新生成必 28P01）。
PG_EXISTING_DB=0

# 新库自动生成时置 1，供安装完成页"显示一次"；展示后由调用方清 0。
PG_PASSWORD_SHOW_ONCE=0

# 沿用已有库 + 用户填了口令但库尚未运行时置 1，表示"起库后需 ALTER ROLE 对齐一次"。
PG_ALIGN_PENDING=0

# 卸载侧写 .appstate：只在"该口令已被库验证通过"时才落盘，否则不写（避免坏快照毒化下次安装）。
record_appstate_password() { # dataroot pw verified(0/1)
    local dataroot="$1" pw="${2-}" verified="${3:-0}" dir
    dir="${dataroot}/.appstate"
    if [ "$verified" != "1" ]; then
        echo "note: 口令未经验证，不写 .appstate（防坏快照）。" >&2
        rm -f "${dir}/pg_password" 2>/dev/null
        return 0
    fi
    mkdir -p "$dir"
    umask 077
    printf '%s\n' "$pw" > "${dir}/pg_password"
    echo "已写入 .appstate/pg_password（口令已经 TCP 验证通过）。"
}

# 公开生成入口：沿用库路径下调用即 fail，防止 install_callback 里的"二次生成"污染口令。
generate_pg_password() {
    if [ "$PG_EXISTING_DB" = "1" ]; then
        echo "REFUSE: 沿用已有库模式下禁止重新生成新口令（会 28P01）；应取该库口令或 ALTER ROLE 对齐。"
        return 1
    fi
    _gen_pg_password_raw
}

# 守卫写入：只有合规值才写，否则拒绝（返回非 0）且不碰原文件。
write_pg_password_guarded() {
    local dest="$1" value="${2-}"
    local v
    v=$(printf '%s' "$value" | tr -d '\r\n')
    if ! pg_password_is_valid "$v"; then
        echo "REFUSE: 拒绝把占位符/过短值写入口令文件 ${dest}（value=$(mask_or_short "$v")）"
        return 1
    fi
    install -m 600 /dev/null "$dest" 2>/dev/null || { umask 077; : > "$dest"; }
    printf '%s\n' "$v" > "$dest"
    chmod 600 "$dest" 2>/dev/null || true
    echo "写入口令文件 ${dest}（len=${#v}）"
    return 0
}

mask_or_short() { # 短值/占位符直接展示前 8 字符（本就是无意义的占位符）
    local v="$1"; printf '%s' "${v:0:8}"
}

# .appstate 回填：只认"合规 且 与连接串一致"的值，否则忽略并 warn（不写）。
refill_pg_password_from_appstate() {
    local dest="$1" appstate_pw="${2-}" conn_pw="${3-}"
    local ap ap_t cp
    ap_t=$(printf '%s' "$appstate_pw" | tr -d '\r\n')
    cp=$(printf '%s' "$conn_pw" | tr -d '\r\n')

    if ! pg_password_is_valid "$ap_t"; then
        echo "WARN: .appstate 里的 pg_password 不合规（占位符/过短），忽略，不写 ${dest}"
        return 1
    fi
    if [ "$ap_t" != "$cp" ]; then
        echo "WARN: .appstate 的 pg_password 与连接串不一致，忽略（不写 ${dest}）"
        return 1
    fi
    write_pg_password_guarded "$dest" "$ap_t"
    return $?
}


# 用新口令 ALTER ROLE 对齐已有库（只起 db、只改角色口令，不动数据）。
# 用新口令 ALTER ROLE 对齐已有库。走容器内 trust 通道（unix socket，不 -h TCP），
# 因为沿用旧库时"当前配置口令"对旧库的 TCP+scram 天然不认，走 TCP 会 28P01 静默失败。
# 改完必须用新口令走 TCP 试连一次验证；验证失败 → fail 并保留脱敏诊断。
DB_CONTAINER="${DB_CONTAINER:-mail-archiver-fnos-db}"
DB_BIN="${DB_BIN:-docker}"     # 拆成两个词，避免"docker exec"被判成单个命令名
DB_SUB="${DB_SUB:-exec}"
TCP_VERIFY_HOST="${TCP_VERIFY_HOST:-postgres}"

db_alter_password() {
    local host="$1" user="$2" db="$3" new="$4"   # host 仅保留签名兼容，实际走 DB_CONTAINER
    local esc out rc out2 rc2
    esc=$(printf '%s' "$new" | sed "s/'/''/g")

    out=$("$DB_BIN" "$DB_SUB" "$DB_CONTAINER" psql -U "$user" -d "$db" -v ON_ERROR_STOP=1 \
        -c "ALTER ROLE \"${user}\" WITH PASSWORD '${esc}'" 2>&1); rc=$?
    if [ $rc -ne 0 ]; then
        echo "FAIL: trust 通道 ALTER 失败（${out}）。" >&2
        echo "      请确认 db 容器可执行 psql 且 pg_hba 含 local trust；可手工执行：" >&2
        echo "      docker exec ${DB_CONTAINER} psql -U ${user} -d ${db} -c \"ALTER ROLE ${user} WITH PASSWORD '<新口令>';\"" >&2
        return 1
    fi

    out2=$("$DB_BIN" "$DB_SUB" -e PGPASSWORD="$new" "$DB_CONTAINER" psql -h "$TCP_VERIFY_HOST" -U "$user" -d "$db" -tAc 'select 1' 2>&1); rc2=$?
    if [ $rc2 -ne 0 ]; then
        echo "FAIL: ALTER 已执行，但新口令走容器内 TCP 验证失败（${out2}）。" >&2
        echo "      诊断（脱敏）：新口令指纹 $(db_fingerprint "$new")" >&2
        return 1
    fi
    echo "ALTER ROLE 完成，且新口令容器内 TCP 验证通过（指纹 $(db_fingerprint "$new")）"
    return 0
}

# 只读验证：该口令能否走容器内 TCP 连上库（供 resolve/卸载侧判断是否"已被库验证"）。
db_password_verified() { # db_container user db pw  -> 0/1
    local c="$1" user="$2" db="$3" pw="$4" out rc
    out=$("$DB_BIN" "$DB_SUB" -e PGPASSWORD="$pw" "$c" psql -h "$TCP_VERIFY_HOST" -U "$user" -d "$db" -tAc 'select 1' 2>&1); rc=$?
    return $rc
}

# 校验数据目录的 pgdata 完整性（四态）。
#   1) 路径不存在          -> 通过（全新，待 initdb）
#   2) 存在但为空          -> 通过（全新/待初始化；含只有空子目录）
#   3) 非空 且 有 PG_VERSION -> 通过（base/pg_control 缺失仅 warn 不 fail）
#   4) 非空 但 缺 PG_VERSION -> fail（真坏库，可能上次迁移/初始化中断）
assert_pgdata_complete() {
    local pgdata="$1"
    [ -d "$pgdata" ] || return 0

    local head
    head=$(find "$pgdata" -mindepth 1 \( -type f -o -type l \) -print -quit 2>/dev/null)
    if [ -z "$head" ]; then
        return 0                                          # 无任何文件（含只有空子目录）：全新待初始化
    fi

    if [ ! -f "$pgdata/PG_VERSION" ]; then
        echo "FAIL: 该数据目录的数据库不完整（缺 PG_VERSION），可能上次迁移/初始化中断；请换用完整目录或新目录。" >&2
        return 1
    fi

    if [ ! -d "$pgdata/base" ] || [ -z "$(find "$pgdata/base" -mindepth 1 -print -quit 2>/dev/null)" ]; then
        echo "warn: 数据库可能不完整（base 缺失或为空），继续但请留意。"
    fi
    if [ ! -f "$pgdata/global/pg_control" ]; then
        echo "warn: 未见 global/pg_control，继续但请留意。"
    fi
    return 0
}

# 沿用已有库（B1/B3）时解析 pg_password。优先级：.appstate 合规 → 用；否则起库 ALTER ROLE 对齐；失败 fail。
# 参数：dataroot cfgfile dbhost dbuser dbname ；返回 0 并把最终口令写到 stdout，1 = fail。
resolve_pg_password_for_existing_db() {
    local dataroot="$1" cfgfile="$2" dbhost="${3:-skip}" dbuser="${4:-mailarchiver}" dbname="${5:-mailarchiver}"
    local appstate pw
    PG_EXISTING_DB=1   # 该路径下禁用公开 generate_pg_password（内部用 _gen_pg_password_raw）

    appstate="${dataroot}/.appstate/pg_password"
    if [ -r "$appstate" ]; then
        pw=$(tr -d '\r\n' < "$appstate")
        if pg_password_is_valid "$pw"; then
            echo "[resolve] #1 沿用已有库：采用 .appstate 真口令（len=${#pw}）" >&2
            write_pg_password_guarded "$cfgfile" "$pw" >/dev/null
            printf '%s\n' "$pw"
            return 0
        fi
        echo "[resolve] warn: .appstate/pg_password 不合规（占位符/过短），忽略" >&2
    fi

    # #2 无 .appstate 真口令 → 起库对齐
    if [ "$dbhost" = "skip" ] || ! command -v psql >/dev/null 2>&1; then
        echo "FAIL: 沿用已有库但无法取到口令：.appstate 缺失/不合规，且无可用 psql 做 ALTER ROLE。" >&2
        echo "      请手工对齐后重装：ALTER ROLE ${dbuser} WITH PASSWORD '<新口令>';"
        return 1
    fi

    local new; new=$(_gen_pg_password_raw)
    echo "[resolve] #2 沿用已有库：起库并对齐（ALTER ROLE ${dbuser}）" >&2
    if ! db_alter_password "$dbhost" "$dbuser" "$dbname" "$new" >/dev/null 2>&1; then
        echo "FAIL: ALTER ROLE 对齐失败（库拒绝连接或用户不存在）。" >&2
        echo "      请确认可连接 ${dbuser}@${dbhost}/${dbname} 后再装，或手工对齐。"
        return 1
    fi
    write_pg_password_guarded "$cfgfile" "$new" >/dev/null
    printf '%s\n' "$new"
    return 0
}


# 三态口令解析（安装完成后调用）：mode ∈ new|existing；wizard_pw 为向导「数据库口令（可选）」。
# 返回最终口令到 stdout（诊断走 stderr）；PG_PASSWORD_SHOW_ONCE=1 表示"自动生成、需显示一次"。
resolve_db_password() {
    local mode="${1:-new}" wizard_pw="${2-}" dataroot="${3-}" cfgfile="$4" dbhost="${5:-skip}" dbuser="${6:-mailarchiver}" dbname="${7:-mailarchiver}"
    local pw appstate

    PG_PASSWORD_SHOW_ONCE=0

    if [ "$mode" = "existing" ]; then
        PG_EXISTING_DB=1
        # 1) .appstate 合规 → 采用（不 ALTER、不生成）
        appstate="${dataroot}/.appstate/pg_password"
        if [ -r "$appstate" ]; then
            pw=$(tr -d '\r\n' < "$appstate")
            if pg_password_is_valid "$pw"; then
                echo "[resolve] 沿用库：#1 采用 .appstate 口令（len=${#pw}）" >&2
                write_pg_password_guarded "$cfgfile" "$pw" >/dev/null
                printf '%s\n' "$pw"; return 0
            fi
            echo "[resolve] warn: .appstate/pg_password 不合规，忽略" >&2
        fi
        # 2) 向导填了 → 对齐该库；库尚未运行则"记录待对齐"，不在校验阶段 fail
        if [ -n "$wizard_pw" ]; then
            if ! pg_password_is_valid "$wizard_pw"; then
                echo "FAIL: 填写的数据库口令过短或为占位符（≥16 位）。" >&2; return 1
            fi
            if [ "$dbhost" = "skip" ] || ! command -v pg_isready >/dev/null 2>&1 || ! pg_isready -h "$dbhost" -U "$dbuser" -d "$dbname" >/dev/null 2>&1; then
                PG_ALIGN_PENDING=1
                write_pg_password_guarded "$cfgfile" "$wizard_pw" >/dev/null
                echo "note: 库尚未运行，记录待对齐（起库后 ALTER ROLE ${dbuser} 一次，不在校验阶段判 fail）。" >&2
                printf '%s\n' "$wizard_pw"; return 0
            fi
            if ! db_alter_password "$dbhost" "$dbuser" "$dbname" "$wizard_pw" >/dev/null 2>&1; then
                echo "FAIL: 该库的口令不匹配，请填写该库当初的数据库口令。" >&2; return 1
            fi
            write_pg_password_guarded "$cfgfile" "$wizard_pw" >/dev/null
            printf '%s\n' "$wizard_pw"; return 0
        fi
        # 3) 都没有 → 自动生成 + 待对齐（起库后 ALTER ROLE），不再是死路
        echo "[resolve] 沿用库：#3 未找到旧口令，自动生成并待对齐（邮件数据未改动）。" >&2
        pw="$(_gen_pg_password_raw)"
        PG_ALIGN_PENDING=1
        write_pg_password_guarded "$cfgfile" "$pw" >/dev/null
        printf '%s\n' "$pw"; return 0
    fi

    # new
    PG_EXISTING_DB=0
    if [ -n "$wizard_pw" ]; then
        if ! pg_password_is_valid "$wizard_pw"; then
            echo "FAIL: 数据库口令过短或为占位符（≥16 位）。" >&2; return 1
        fi
        write_pg_password_guarded "$cfgfile" "$wizard_pw" >/dev/null
        printf '%s\n' "$wizard_pw"; return 0
    fi
    pw=$(_gen_pg_password_raw)
    write_pg_password_guarded "$cfgfile" "$pw" >/dev/null
    PG_PASSWORD_SHOW_ONCE=1
    printf '%s\n' "$pw"; return 0
}


# ---- 模板污染 / "-s 短路" 修复 ----

# 回填：dest 缺失、为空或不合规（含占位符模板 change_me）→ 用权威 src 回填并写回。
# 这样就不再有"模板非空 ⇒ 跳过回填"的短路。返回最终值（stdout）。
backfill_pg_password() {
    local dest="${1-}" src="${2-}" cur src_pw
    [ -r "$src" ] || { echo "FAIL: 权威口令源不存在: ${src}" >&2; return 1; }
    src_pw=$(tr -d '\r\n' < "$src")
    if ! pg_password_is_valid "$src_pw"; then
        echo "FAIL: 权威口令本身不合规（占位符/过短），无法回填。" >&2; return 1
    fi

    cur=""
    [ -r "$dest" ] && cur=$(tr -d '\r\n' < "$dest")

    if pg_password_is_valid "$cur" && [ "$cur" = "$src_pw" ]; then
        echo "note: 副本已是合规一致值，不覆盖" >&2
        printf '%s\n' "$cur"; return 0
    fi

    echo "note: 副本缺失/占位/不一致 → 用权威值回填" >&2
    write_pg_password_guarded "$dest" "$src_pw" >/dev/null
    printf '%s\n' "$src_pw"; return 0
}

# ensure_payload 专用：只认 ${CFG_DIR}/pg_password 一个权威源，绝不把 @appcenter 模板当口令。
# 若权威源不合规 → fail（不允许从别处找补）。
ensure_payload_pg_password() {
    local dest="$1" cfg_src="$2"
    if [ ! -r "$cfg_src" ]; then
        echo "FAIL: 权威口令缺失且禁止用模板兜底: ${cfg_src}" >&2; return 1
    fi
    backfill_pg_password "$dest" "$cfg_src"
}

# 顺序自检辅助：模拟"写值 → 自检读值"两步的值一致性。
# usage: pass1=$(backfill…); pass2 自检应等于 pass1；等价于"自检读到的 sha == 最终载荷文件 sha"。


# ---- 数据库口令：可见输出 + 受控指纹查看（不落明文持久文件） ----

db_fingerprint() { # <pw> -> "len=… sha8=…"
    local v="$1" n h
    v=$(printf '%s' "$v" | tr -d '\r\n'); n=${#v}
    h=$(printf '%s' "$v" | sha256sum | cut -c1-8)
    echo "len=${n} sha8=${h}"
}

# 安装完成页醒目块：只显示这一次明文（SHOW_ONCE 场景），否则只显示指纹。
print_db_credential_note() {
    local pw="$1" show_once="${2:-0}"
    cat <<EOF
============================================================
 数据库口令（数据库连接用，不是管理员登录密码）
============================================================
EOF
    if [ "$show_once" = "1" ] && [ -n "$pw" ]; then
        printf ' 密码：%s\n' "$pw"
        printf ' （仅显示这一次，请自行保存；指纹 %s）\n' "$(db_fingerprint "$pw")"
    else
        printf ' 密码不在此显示（出于安全不再打印明文）。\n'
        printf ' 指纹 %s\n' "$(db_fingerprint "$pw")"
    fi
    printf ' 如需核对，运行：--show-db-fingerprint（只显示指纹与长度，不回显明文）\n'
    echo "============================================================"
}

# 受控入口：只输出指纹与长度，绝不回显明文。
show_db_fingerprint() { # <pg_password_file> 或 <pw>
    local arg="$1" v
    if [ -r "$arg" ]; then
        v=$(tr -d '\r\n' < "$arg")
    else
        v="$arg"
    fi
    if ! pg_password_is_valid "$v"; then
        echo "（该值不合规/为占位符，指纹无意义）"
        db_fingerprint "$v"
        return 1
    fi
    db_fingerprint "$v"
    return 0
}


# ---- 数据库口令明文：不做额外落盘文件（明文本就存在 ${CFG_DIR}/pg_password，600） ----
# 安全边界：不新增任何持久明文文件；明文只在应用配置目录的 pg_password（600、应用用户可读），
# 不上传、不进日志、不进 Release。

# 受控查看：直接读 pg_password 文件（600 天然受控），回显明文 + 提示；缺失/占位符 → 非 0。
show_db_password() { # <pg_password_file>
    local file="$1" v
    if [ -n "$file" ] && [ -r "$file" ]; then
        v=$(tr -d '\r\n' < "$file")
        if pg_password_is_valid "$v"; then
            printf '%s\n' "$v"
            echo "（该文件为 600，仅本机管理员可读）" >&2
            return 0
        fi
        echo "口令不合规/为占位符（指纹无意义）" >&2
        db_fingerprint "$v"
        return 1
    fi
    echo "未保存明文（文件缺失或不可读）。" >&2
    return 1
}
