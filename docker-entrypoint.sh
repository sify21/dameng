#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$(id -u)" == "0" ]]; then
    mkdir -p "${DM_DATA_PATH}"
    chown dmdba:dinstall "${DM_DATA_PATH}"
    exec gosu dmdba "$0" "$@"
fi

if [[ "${1:-dmserver}" != "dmserver" ]]; then
    exec "$@"
fi
shift $(( $# > 0 ? 1 : 0 ))

mkdir -p "${DM_DATA_PATH}"

ini_file="$(find "${DM_DATA_PATH}" -mindepth 2 -maxdepth 2 \
    -type f -name dm.ini -print -quit)"

if [[ -z "${ini_file}" ]]; then
    echo "正在初始化达梦数据库实例 ${DB_NAME} ..."
    charset="${CHARSET:-${UNICODE_FLAG}}"
    dminit \
        "PATH=${DM_DATA_PATH}" \
        "DB_NAME=${DB_NAME}" \
        "INSTANCE_NAME=${INSTANCE_NAME}" \
        "PORT_NUM=${PORT_NUM}" \
        "PAGE_SIZE=${PAGE_SIZE}" \
        "CASE_SENSITIVE=${CASE_SENSITIVE}" \
        "CHARSET=${charset}" \
        "ARCH_FLAG=${ARCH_FLAG}" \
        "SYSDBA_PWD=${SYSDBA_PWD}" \
        "SYSAUDITOR_PWD=${SYSAUDITOR_PWD}"
    ini_file="${DM_DATA_PATH}/${DB_NAME}/dm.ini"
fi

test -f "${ini_file}"
echo "使用配置 ${ini_file} 启动达梦数据库"
exec dmserver "${ini_file}" -noconsole "$@"
