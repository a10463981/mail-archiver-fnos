#!/bin/sh
# 占位镜像入口：按 LISTEN_UNIX_SOCKET 生成完整 nginx 主配置到 /tmp（容器内只有 /tmp 保证可写），
# 启动后 socket 一出现立刻 chmod 600。
# 正式镜像（Kestrel）等价逻辑：ListenUnixSocket(...) + 启动后同一段 chmod 600。
set -eu

SOCK="${LISTEN_UNIX_SOCKET:-/tmp/app.sock}"

# 冷启动兜底：平台可能在 install_callback 之前就用占位 app.env 拉起容器，
# 此时目标目录可能还不存在/不可写 —— 绝不能因为建不了 socket 目录就让容器崩掉（会让安装失败）。
if mkdir -p "$(dirname "$SOCK")" 2>/dev/null && touch "$(dirname "$SOCK")/.wtest" 2>/dev/null; then
    rm -f "$(dirname "$SOCK")/.wtest"
else
    echo "[mail-archiver-fnos] WARN: $(dirname "$SOCK") 不可写，回落 /tmp/app.sock（冷启动）" >&2
    SOCK=/tmp/app.sock
fi
rm -f "$SOCK"

# 生成完整主配置：容器以非 root 运行，只能写 /tmp
cat >/tmp/nginx.conf <<CONF
worker_processes 1;
pid /tmp/nginx.pid;
error_log /dev/stderr warn;

events { worker_connections 256; }

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /dev/stdout;
    client_body_temp_path /tmp/client_body;
    proxy_temp_path /tmp/proxy;
    fastcgi_temp_path /tmp/fastcgi;
    uwsgi_temp_path /tmp/uwsgi;
    scgi_temp_path /tmp/scgi;
    server_tokens off;

    server {
        listen unix:${SOCK};
        root /usr/share/nginx/html;

        location = /app/mail-archiver-fnos {
            return 302 /app/mail-archiver-fnos/;
        }

        location = /app/mail-archiver-fnos/__whoami {
            default_type text/plain;
            add_header X-Echo-Userid   \$http_x_trim_userid   always;
            add_header X-Echo-Username \$http_x_trim_username always;
            add_header X-Echo-Isadmin  \$http_x_trim_isadmin  always;
            return 200 "whoami-ok\n";
        }

        location /app/mail-archiver-fnos/ {
            alias /usr/share/nginx/html/;
            index index.html;
            add_header X-Echo-Userid   \$http_x_trim_userid   always;
            add_header X-Echo-Username \$http_x_trim_username always;
            add_header X-Echo-Isadmin  \$http_x_trim_isadmin  always;
        }

        location / {
            return 404;
        }
    }
}
CONF

nginx -c /tmp/nginx.conf -g 'daemon off;' &
NGINX_PID=$!

i=0
while [ ! -S "$SOCK" ] && [ "$i" -lt 100 ]; do
    i=$((i + 1))
    sleep 0.1
done

if [ -S "$SOCK" ]; then
    chmod 600 "$SOCK"
    echo "[mail-archiver-fnos] socket ready: $(ls -l "$SOCK")"
else
    echo "[mail-archiver-fnos] WARN: socket not created in 10s ($SOCK)" >&2
fi

trap 'kill -TERM "$NGINX_PID" 2>/dev/null || true' TERM INT
wait "$NGINX_PID"
