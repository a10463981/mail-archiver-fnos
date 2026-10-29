FROM nginx:1.27-alpine

# 占位镜像：只为验证 fpk 骨架（安装/网关/免登录头/中文/数据保留）。
# 正式构建时本目录整体替换为上游 39f59d2 + patch，tag 保持 mail-archiver-fnos:zh-<commit>。
COPY entrypoint.sh /entrypoint.sh
COPY html/ /usr/share/nginx/html/
# 容器以 TRIM_UID 非 root 运行：所有文件必须 world-readable，脚本必须 755（否则 Permission denied）
RUN chmod 755 /entrypoint.sh && chmod -R a+rX /usr/share/nginx/html
CMD ["/entrypoint.sh"]
