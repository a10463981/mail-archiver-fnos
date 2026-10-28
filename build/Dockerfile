# Mail-Archiver — fnOS (飞牛) fpk build.
#
# Differences from the upstream Dockerfile:
#   * no TCP endpoint is published: the fnOS unified gateway connects to a unix domain socket
#     (LISTEN_UNIX_SOCKET) and the socket is tightened to 0600 at startup by
#     Services/UnixSocketPermissionService.cs. See the fpk delivery notes.
#   * ASPNETCORE_URLS is intentionally NOT set. With LISTEN_UNIX_SOCKET the application clears
#     every configured TCP endpoint; without it Kestrel falls back to http://localhost:5000,
#     which is loopback-only — the right default for local debugging.
#
# Build (note the ARG for the pinned upstream commit used to produce the patch):
#   docker build -t mailarchiver-fnos:p1 .

FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /app

COPY . ./
RUN dotnet restore MailArchiver.csproj \
 && dotnet publish MailArchiver.csproj -c Release -o out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime

# MailKit needs libgssapi_krb5.so.2 for Kerberos/GSSAPI IMAP authentication.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgssapi-krb5-2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/out ./

# The fpk runs the container as the package user (non-root, e.g. TRIM_UID). The published files
# are owned by root, so make them world-readable and traversable — but deliberately NOT writable:
# appsettings.json is configuration, not state.
# Normalise the published tree: readable/traversable by everyone, writable only by the owner.
# (A plain "chmod -R a+rX" only ADDS bits — it would leave behind any group/other write bit that
# came in through the build context, and appsettings.json was measured as 0777 that way.)
RUN chmod -R u+rwX,go+rX,go-w /app \
 && chmod 0444 /app/appsettings.json

# Writable state directories.
#
# They must exist and be writable by an *unknown* uid, because the fpk runs the container as the
# package user (TRIM_UID). Creating them in the entrypoint is not possible: /app is root-owned and
# 0755, so a non-root process cannot mkdir underneath it — measured: the container died at start-up
# with "Access to the path '/app/uploads' is denied".
#
# 0777 (deliberately NOT the 1777 used in the ad-hoc workaround) is scoped to these four leaf
# directories only, never recursive, and they live inside the image layer — not on a host bind
# mount — so nothing outside the container is exposed. Files written into them still get 0600 from
# the 0077 umask and are owned by the runtime user.
# For persistence the fpk should bind-mount these paths under ${TRIM_PKGVAR}; the host directory's
# ownership then governs and this mode is irrelevant.
RUN mkdir -p /app/uploads /app/uploads/eml /app/uploads/mbox /app/exports /app/exports/audit \
             /app/logs /app/DataProtection-Keys \
 && chmod 0777 /app/uploads /app/uploads/eml /app/uploads/mbox /app/exports /app/exports/audit \
               /app/logs /app/DataProtection-Keys

ENV ASPNETCORE_ENVIRONMENT=Production
ENV TZ=UTC

# Upstream parity for standalone (non-fpk) use: listen on TCP 5000 like the official image.
# When LISTEN_UNIX_SOCKET is set, Program.cs clears every configured URL before configuring
# Kestrel, so this endpoint is NOT created in the fpk — verified on a live instance: no TCP
# socket is listening and no port is published.
ENV ASPNETCORE_URLS=http://+:5000

# Mount points used by the fpk lifecycle scripts:
#   /app/DataProtection-Keys  -> must persist, otherwise every restart invalidates the auth cookies
#   /app/logs                 -> optional
# The socket itself lives in the fnOS app target directory (${TRIM_APPDEST}) and is passed in
# through LISTEN_UNIX_SOCKET, e.g. /var/apps/mailarchiver-fnos/target/app.sock

# Socket permissions are the ONLY trust boundary for the identity headers injected by the fnOS
# gateway, so the socket must never exist in a world-accessible state — not even for the few
# milliseconds before a background poll could chmod it.
#
# `umask 0077` (NOT 0177) is what makes that atomic. Measured on a live instance:
#   * socket    — created as 0700 (0777 & ~0077). Owner-only: no group/other bits, so no other
#                 local user can connect (connect() needs write permission). The application then
#                 narrows it to 0600; the two are equivalent for a socket.
#   * directory — created as 0700 (0777 & ~0077): owner-only AND traversable, which is what a
#                 directory needs.
# With umask 0177 the socket would also be 0600 — but directories would come out as 0600, i.e.
# without the execute bit, so the owner cannot even enter the directory it just created. The mkdir
# itself succeeds and the failure only surfaces later as "Permission denied" on the first write.
# That silently breaks every directory the application creates at runtime: /app/exports,
# /app/uploads/eml, /app/uploads/mbox, the audit-export output directory and
# /app/DataProtection-Keys (the last one would invalidate every session on restart).
#
# The application still re-applies the socket mode at start-up as a belt-and-braces check and
# refuses to trust gateway headers if that fails (fail-closed).
#
# Writable directories are created HERE, not at build time: the container may run as any uid
# (fnOS passes TRIM_UID), so build-time directories would be owned by root and the service would
# fail on the first write (crash loop). Creating them at start-up as the runtime user gives the
# correct owner without resorting to a world-writable 1777.
# umask 0077 makes them 0700 — sufficient for this process (it is the owner) and not readable by
# other local users, which is what we want for archived mail and the DataProtection keys.
ENTRYPOINT ["/bin/sh", "-c", "umask 0077; mkdir -p /app/uploads /app/uploads/eml /app/uploads/mbox /app/exports /app/exports/audit /app/logs /app/DataProtection-Keys 2>/dev/null || true; exec dotnet MailArchiver.dll"]
