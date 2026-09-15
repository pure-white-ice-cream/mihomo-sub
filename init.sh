#!/bin/sh
# Mihomo + Subconverter 容器启动脚本

SUB_SCRIPT="/usr/local/bin/sub.sh"
CONFIG_DIR="/root/.config/mihomo"
LOG_FILE="${CONFIG_DIR}/log.txt"
SECRET_FILE="${CONFIG_DIR}/.secret"
TOKEN_FILE="${CONFIG_DIR}/.sub_token"
SUBCONV_DIR="/subconverter"

echo "=========================================="
echo " Mihomo Sub 容器正在启动..."
echo "=========================================="

mkdir -p "${CONFIG_DIR}" "${SUBCONV_DIR}/profiles"

# ---------------------------
# 默认值
# ---------------------------
MIXED_PORT="${MIXED_PORT:-7890}"
CONTROLLER_PORT="${CONTROLLER_PORT:-9090}"
ALLOW_LAN="${ALLOW_LAN:-true}"
export MIXED_PORT CONTROLLER_PORT ALLOW_LAN

case "${cron}" in
  off|OFF|none|NONE|false|FALSE)
    cron_disabled=1
    ;;
  "")
    cron="0 4 * * *"
    cron_disabled=0
    ;;
  *)
    cron_disabled=0
    ;;
esac
export cron

# ---------------------------
# 持久化密钥：SECRET=off 关闭；否则 环境变量 > 数据卷 > 新生成
# ---------------------------
secret_label=""
case "${SECRET}" in
  off|OFF|none|NONE|false|FALSE|disable|DISABLE|disabled|DISABLED)
    SECRET=""
    : > "${SECRET_FILE}"
    secret_label="未启用（面板无密钥）"
    echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] SECRET=off，面板不设密钥。仅建议局域网使用"
    ;;
  "")
    if [ -f "${SECRET_FILE}" ] && [ -s "${SECRET_FILE}" ]; then
      SECRET=$(tr -d '[:space:]' < "${SECRET_FILE}")
    else
      SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
      printf '%s' "${SECRET}" > "${SECRET_FILE}"
      echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] 未设置 SECRET，已生成随机密钥并写入数据卷"
    fi
    ;;
  *)
    printf '%s' "${SECRET}" > "${SECRET_FILE}"
    ;;
esac
chmod 600 "${SECRET_FILE}" 2>/dev/null || true
export SECRET
if [ -z "${secret_label}" ]; then
  secret_label="${SECRET}"
fi

if [ -n "${SUB_TOKEN}" ]; then
  printf '%s' "${SUB_TOKEN}" > "${TOKEN_FILE}"
elif [ -f "${TOKEN_FILE}" ] && [ -s "${TOKEN_FILE}" ]; then
  SUB_TOKEN=$(tr -d '[:space:]' < "${TOKEN_FILE}")
else
  SUB_TOKEN=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)
  printf '%s' "${SUB_TOKEN}" > "${TOKEN_FILE}"
  echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] 未设置 SUB_TOKEN，已生成随机令牌并写入数据卷"
fi
chmod 600 "${TOKEN_FILE}" 2>/dev/null || true
export SUB_TOKEN

# ---------------------------
# 写入 subconverter 鉴权，避免 25500 被误映射后裸奔
# ---------------------------
configure_subconverter() {
  if [ -f "${SUBCONV_DIR}/pref.yml" ] && command -v yq >/dev/null 2>&1; then
    yq -i ".common.api_access_token = \"${SUB_TOKEN}\" | .common.api_mode = true" \
      "${SUBCONV_DIR}/pref.yml" 2>/dev/null || true
  fi
  if [ -f "${SUBCONV_DIR}/pref.yaml" ] && command -v yq >/dev/null 2>&1; then
    yq -i ".common.api_access_token = \"${SUB_TOKEN}\" | .common.api_mode = true" \
      "${SUBCONV_DIR}/pref.yaml" 2>/dev/null || true
  fi
  if [ -f "${SUBCONV_DIR}/pref.ini" ]; then
    if grep -q '^api_access_token' "${SUBCONV_DIR}/pref.ini"; then
      sed -i "s|^api_access_token=.*|api_access_token=${SUB_TOKEN}|" "${SUBCONV_DIR}/pref.ini"
    elif grep -q '^\[common\]' "${SUBCONV_DIR}/pref.ini"; then
      sed -i "/^\[common\]/a api_access_token=${SUB_TOKEN}" "${SUBCONV_DIR}/pref.ini"
    else
      printf '\n[common]\napi_access_token=%s\n' "${SUB_TOKEN}" >> "${SUBCONV_DIR}/pref.ini"
    fi
    if grep -q '^api_mode' "${SUBCONV_DIR}/pref.ini"; then
      sed -i "s|^api_mode=.*|api_mode=true|" "${SUBCONV_DIR}/pref.ini"
    elif grep -q '^\[common\]' "${SUBCONV_DIR}/pref.ini"; then
      sed -i "/^\[common\]/a api_mode=true" "${SUBCONV_DIR}/pref.ini"
    fi
  fi
  if [ -f "${SUBCONV_DIR}/pref.toml" ]; then
    if grep -q 'api_access_token' "${SUBCONV_DIR}/pref.toml"; then
      sed -i "s|^api_access_token *=.*|api_access_token = \"${SUB_TOKEN}\"|" "${SUBCONV_DIR}/pref.toml"
    else
      printf '\napi_access_token = "%s"\n' "${SUB_TOKEN}" >> "${SUBCONV_DIR}/pref.toml"
    fi
    if grep -q 'api_mode' "${SUBCONV_DIR}/pref.toml"; then
      sed -i "s|^api_mode *=.*|api_mode = true|" "${SUBCONV_DIR}/pref.toml"
    else
      printf 'api_mode = true\n' >> "${SUBCONV_DIR}/pref.toml"
    fi
  fi
}

write_sub_profiles() {
  # url 由 sub.sh 在每次成功下载后改写
  for target in clash surge quanx singbox; do
    printf '%s\n' "[Profile]" "target=${target}" "url=" "emoji=true" "udp=true" \
      > "${SUBCONV_DIR}/profiles/${target}.ini"
  done
}

configure_subconverter
write_sub_profiles

echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [1/4] 启动 Subconverter 服务..."
/subconverter/subconverter >/dev/null 2>&1 &
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] Subconverter 已后台运行"

if [ "${cron_disabled}" -eq 1 ]; then
  cron_label="已关闭"
else
  cron_label="${cron}"
fi
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [2/4] 配置定时任务 (cron: ${cron_label})..."
if [ "${cron_disabled}" -eq 0 ]; then
  echo "${cron} ${SUB_SCRIPT} >> ${LOG_FILE} 2>&1" > /etc/crontabs/root
  crond -d 8 &
  echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] crond 已后台运行，将按计划更新订阅"
else
  echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] cron 已关闭，跳过定时任务"
fi

echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [3/4] 等待 Subconverter 就绪并执行首次订阅转换..."
i=0
while [ "$i" -lt 15 ]; do
  if curl -sf --max-time 2 "http://127.0.0.1:25500/version" >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done

if "${SUB_SCRIPT}"; then
  echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] 首次订阅转换完成"
else
  echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] 首次订阅转换失败，将尝试使用已有配置启动。详见 ${LOG_FILE}"
fi

echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [4/4] 启动 Mihomo（前台运行）..."
echo "=========================================="
echo " 混合代理:  ${MIXED_PORT}"
echo " Web 面板:  http://<主机IP>:${CONTROLLER_PORT}/ui"
echo " API 密钥:  ${secret_label}"
echo " 订阅令牌:  ${SUB_TOKEN}"
echo " 家庭订阅:  http://<主机IP>:25500/getprofile?name=profiles/clash.ini&token=${SUB_TOKEN}"
echo "            （需在 compose 中映射 25500，切勿直接暴露公网）"
echo " 定时更新:  ${cron_label}"
echo " allow-lan: ${ALLOW_LAN}"
echo "=========================================="

exec /mihomo
