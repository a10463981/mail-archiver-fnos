#!/bin/bash
# 口令一致性自检 v2 —— 0.1.29 用的权威版。
#
# M1：连接串解析支持引号包裹（值内含 `;`）、PasswordFile=；trim 只去首尾空白与 \r\n，绝不删值内部。
# M2：自愈分两条路：
#     (a) 副本缺失/陈旧 → 按权威值对齐（放行 + 日志）；
#     (b) 权威值 vs 库实际口令不一致 → fail（脱敏对比 + 排查指引），不静默覆盖。
#         判定方式 = 用权威口令 + psql 只读试连（select 1），无任何写入。

set -u

# ---- 工具 ----
trim_ws() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//' -e 's/^\xEF\xBB\xBF//'; }

mask() { # mask <string> -> "len=… head=… sha=…"（不打印明文）
    local s="$1" n h
    n=${#s}
    if [ "$n" -eq 0 ]; then echo "len=0 head=(empty) sha=(empty)"; return 0; fi
    h=$(printf '%s' "$s" | sha256sum | cut -c1-8)
    echo "len=${n} head=${s:0:4} sha=${h}"
}

# 从 Npgsql 连接串里取 Password= 的值；无 Password= 但有 PasswordFile= 则读文件；都不在则为空。
extract_conn_password() {
    local conn="$1" pfile v
    pfile=$(printf '%s' "$conn" | grep -oE '[Pp]asswordFile=[^;]*' | head -1 | cut -d= -f2- | sed -e "s/^'//;s/'$//;s/^\"//;s/\"$//")
    if [ -n "$pfile" ] && [ -r "$pfile" ]; then
        cat "$pfile" 2>/dev/null; return 0
    fi
    # 先试引号包裹 Password='…'，再退化为不带引号 Password=…（到 ; 止）
    v=$(printf '%s' "$conn" | grep -oE "[Pp]assword='[^']*'" | head -1 | cut -d= -f2- | sed -e "s/^'//;s/'$//")
    if [ -z "$v" ]; then
        v=$(printf '%s' "$conn" | grep -oE "[Pp]assword=[^;]*" | head -1 | cut -d= -f2-)
    fi
    printf '%s' "$v" | tr -d '\r\n'
}

# 用权威口令连一次库（只读 select 1）验证"库实际口令 == 权威值"。
# ---- 库口令比对前置门：库没初始化就跳过，不做试连（否则新库首启任何口令都 28P01）----

# 库是否已就绪（pg_isready 通过）。pg_isready 不可用 → 视为"跳过"（不能拿不可用当不一致）。
pg_database_ready() {
    command -v pg_isready >/dev/null 2>&1 || return 1
    pg_isready -h "$1" -U "$2" -d "$3" >/dev/null 2>&1
}

# 三态库口令比对：0=ok(连上且口令对)  1=skip(容器未起/库未初始化，不做比对)  2=mismatch(连上但口令错)
db_password_match() {
    local host="$1" user="$2" db="$3" pw="$4" out rc
    if ! pg_database_ready "$host" "$user" "$db"; then
        echo "skip: 容器未运行/库未初始化（新库首启，正常），跳过库口令比对。"
        return 1
    fi
    out=$(PGPASSWORD="$pw" psql -v ON_ERROR_STOP=1 -h "$host" -U "$user" -d "$db" -tAc 'select 1' 2>&1); rc=$?
    if [ $rc -eq 0 ]; then
        echo "ok: 库口令与配置一致。"
        return 0
    fi
    echo "mismatch: 库口令与配置不一致（${out}）"
    return 2
}

# 参数：host  user  dbname  password ；0=口令对，1=fail（上层用三态 db_password_match）。

# ---- M1：只比两个字符串，处理引号/内部空格；返回 0=一致 1=不一致（无 DB 探测）----
pg_password_consistent() {
    local pg="$1" conn="$2" conn_pwd pg_t conn_t
    pg_t=$(trim_ws "$(printf '%s' "$pg" | tr -d '\r\n')")
    if [ -z "$pg_t" ]; then
        echo "note: pg_password 为空，判定为「一侧为空，补齐后放行」。"
        return 0
    fi
    conn_pwd=$(extract_conn_password "$conn")
    conn_t=$(trim_ws "$conn_pwd")
    if [ -z "$conn_t" ]; then
        echo "note: 连接串无 Password= 段（或 PasswordFile 不可读），判定为「补齐后放行」。"
        return 0
    fi
    if [ "$pg_t" = "$conn_t" ]; then
        echo "OK: pg_password 与连接串 Password= 一致（$(mask "$pg_t")）。"
        return 0
    fi
    echo "FATAL: pg_password 与连接串 Password= 不一致（会 28P01）。"
    echo "       pg_password : $(mask "$pg_t")"
    echo "       conn Password: $(mask "$conn_t")"
    return 1
}

# ---- M2：一体化入口（供 install_callback source 后调用）----
# 参数： pgfile(权威)  conn(连接串)  dbhost dbuser dbname
# 返回值：0=可继续安装；1=必须 fail（真不一致，含权威值≠库）
check_pg_password_file() {
    local pgfile="$1" conn="$2" dbhost="$3" dbuser="$4" dbname="$5"
    local auth copy conn_pw

    [ -r "$pgfile" ] || { echo "FATAL: 权威口令文件不存在/不可读: $pgfile"; return 1; }
    auth=$(trim_ws "$(cat "$pgfile" 2>/dev/null | tr -d '\r\n')")
    [ -n "$auth" ] || { echo "FATAL: 权威口令为空: $pgfile（28P01 无法自愈，请核对 pg_password 载荷）"; return 1; }

    conn_pw=$(extract_conn_password "$conn")
    conn_pw=$(trim_ws "$conn_pw")

    # (a) 副本缺失/陈旧：按权威值对齐 → 放行 + 日志（不影响已存在的库）
    copy=""
    local copyfile=""
    for f in "/run/secrets/pg_password" "${APPDEST:-/nonexist}/docker/pg_password"; do
        [ -r "$f" ] && copyfile="$f" && break
    done
    if [ -n "$copyfile" ]; then copy=$(trim_ws "$(cat "$copyfile" 2>/dev/null | tr -d '\r\n')"); fi

    if [ -z "$copy" ]; then
        echo "口令自检：副本缺失/为空 → 按权威值（$(mask "$auth")）对齐。"
    elif [ "$copy" != "$conn_pw" ] && [ "$copy" != "$auth" ]; then
        echo "口令自检：副本已陈旧（$(mask "$copy")≠权威），按权威值对齐，不 fail。"
    fi

    # (b) 权威值 vs 库实际口令：真不一致才 fail（这是把 28P01 提前挡在安装阶段）
    if [ -n "$conn_pw" ] && [ "$auth" != "$conn_pw" ]; then
        echo "FATAL: 权威口令与连接串 Password= 不一致（会 28P01）。"
        echo "       权威 pg_password : $(mask "$auth")"
        echo "       连接串 Password   : $(mask "$conn_pw")"
        echo "      排查：核对 pg_password 载荷来源与 app.env 渲染值，二者必须同源。"
        return 1
    fi

    # 若 DB 已存在，用权威口令只读试连一次，确认它不是"配置对、库不对"的假象。
    # 前置门：库未初始化（容器 Created / pg_isready 不通）→ skip，不当 mismatch。
    if [ -n "$dbhost" ]; then
        db_password_match "$dbhost" "$dbuser" "$dbname" "$auth"
        case $? in
            0) : ;;                       # ok
            1) : ;;                       # skip（未初始化，放行）—— 新库首启的正常路径
            2) echo "FATAL: 库口令与配置不一致（如上）。库已初始化但口令对不上，请填写该库当初的数据库口令。" >&2
               return 1 ;;
        esac
    fi

    local p
    p=$(pg_password_consistent "$auth" "$conn")
    return $?
}