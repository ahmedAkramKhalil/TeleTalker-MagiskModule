#!/sbin/sh
# ADDOND_VERSION=2

. /tmp/backuptool.functions

files="priv-app/com.teletalker.app/app-release.apk etc/permissions/privapp-permissions-com.teletalker.app.xml etc/sysconfig/config-com.teletalker.app.xml etc/default-permissions/default-permissions-com.teletalker.app.xml"

case "${1}" in
backup|restore)
    for f in ${files}; do
        "${1}_file" "${S}/${f}"
    done
    ;;
esac