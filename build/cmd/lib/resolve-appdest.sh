#!/bin/bash
# resolve_appdest —— 统一的枢纽目录（APPDEST）解析。
# 平台在不同调用点注入 TRIM_APPDEST 的时机并不可靠：实测出现过 main/config_callback 拿到空值,
# 于是拼出 "/docker/docker-compose.yaml" -> "exit status 1: open /docker/..." -> 平台判定安装失败
# 并自动卸载应用（连带删掉 share 数据）。所以所有使用点必须走这里，不得再直接拼 ${APPDEST}。
set -u

# 取到后校验目录存在；返回 0 成功并把结果写入 AD_RESAULT，失败返回 1 并打印原因。
#   $1 可选：调用点名字（用于日志，便于定位是哪个入口拿不到）
resolve_appdest() {
    local where="${1:-unknown}"
    local cand got=""
    for cand in "${TRIM_APPDEST:-}" "/vol1/@appcenter/${APP_NAME}" "/var/apps/${APP_NAME}/target"; do
        [ -n "$cand" ] || continue
        if [ -d "$cand" ]; then got="$cand"; break; fi
    done
    if [ -z "$got" ]; then
        echo "ERROR: 平台未注入 TRIM_APPDEST，且三级兜底目录均不存在（调用点：${where}）。" >&2
        echo "       期望其一存在：${TRIM_APPDEST:-<空>} / /vol1/@appcenter/${APP_NAME} / /var/apps/${APP_NAME}/target" >&2
        return 1
    fi
    printf '%s' "$got"
    return 0
}

# 便捷封装：成功则设置 COMPOSE_FILE 并返回 0；失败返回 1（调用方决定 fail 还是 note+exit 0）。
resolve_compose_file() {
    local where="${1:-unknown}" dest
    if ! dest=$(resolve_appdest "$where"); then return 1; fi
    APPDEST="$dest"
    COMPOSE_FILE="${APPDEST}/docker/docker-compose.yaml"
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "note: 未找到 compose 文件（${COMPOSE_FILE}），调用点 ${where}。" >&2
        return 2
    fi
    return 0
}