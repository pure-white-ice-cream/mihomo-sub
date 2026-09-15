#!/bin/sh
# 读取运行时写入的密钥，避免 HEALTHCHECK 拿不到启动时生成的 SECRET
CONFIG_DIR="/root/.config/mihomo"
PORT="${CONTROLLER_PORT:-9090}"
SECRET=""

if [ -f "${CONFIG_DIR}/.secret" ]; then
  SECRET=$(tr -d '[:space:]' < "${CONFIG_DIR}/.secret")
fi

if [ -n "${SECRET}" ]; then
  curl -fsS --max-time 5 -H "Authorization: Bearer ${SECRET}" \
    "http://127.0.0.1:${PORT}/version" >/dev/null
else
  curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/version" >/dev/null
fi
