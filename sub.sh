#!/bin/sh

# ---------------------------
# 路径与变量
# ---------------------------
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
GOOD_FILE="${CONFIG_DIR}/config.yaml.good"
OVERLAY_FILE="${CONFIG_DIR}/overlay.yaml"
LOG_FILE="${CONFIG_DIR}/log.txt"
SECRET_FILE="${CONFIG_DIR}/.secret"
SUBCONV_DIR="/subconverter"
SUB_UA="${SUB_UA:-clash.meta}"

MIXED_PORT="${MIXED_PORT:-7890}"
CONTROLLER_PORT="${CONTROLLER_PORT:-9090}"
ALLOW_LAN="${ALLOW_LAN:-true}"

mkdir -p "${CONFIG_DIR}"

if [ -z "${SECRET}" ] && [ -f "${SECRET_FILE}" ]; then
  SECRET=$(tr -d '[:space:]' < "${SECRET_FILE}")
fi
if [ -z "${SUB_TOKEN}" ] && [ -f "${CONFIG_DIR}/.sub_token" ]; then
  SUB_TOKEN=$(tr -d '[:space:]' < "${CONFIG_DIR}/.sub_token")
fi

output=""
log=""
exit_code=0

# ---------------------------
# 日志
# ---------------------------
log_msg() {
  msg="$1"
  printf '%s\n' "${msg}"
  log="${log}${msg}
"
}

sub_end() {
  printf '%s' "${log}" >> "${LOG_FILE}"
  exit "${exit_code}"
}

notify() {
  status="$1"
  message="$2"
  if [ -z "${NOTIFY_WEBHOOK}" ]; then
    return 0
  fi
  payload=$(jq -n --arg s "${status}" --arg m "${message}" '{status:$s,message:$m}' 2>/dev/null) || return 0
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
    curl -sS --max-time 10 -X POST -H "Content-Type: application/json" \
    -d "${payload}" "${NOTIFY_WEBHOOK}" >/dev/null 2>&1 || true
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

curl_direct() {
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
    curl -sL --retry 3 --retry-delay 2 --max-time 30 -A "${SUB_UA}" "$@"
}

restore_good_config() {
  if [ -f "${GOOD_FILE}" ]; then
    cp -f "${GOOD_FILE}" "${CONFIG_FILE}"
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 已恢复上一份可用配置"
  fi
}

# ---------------------------
# 必填检查
# ---------------------------
if [ -z "${sub_url}" ]; then
  exit_code=1
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error: sub_url 变量未设置"
  notify "fail" "sub_url 未设置"
  sub_end
fi

# ---------------------------
# 多订阅下载（| 或换行分隔）
# ---------------------------
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 下载订阅文件..."

url_list=$(printf '%s\n' "${sub_url}" | tr '|' '\n' | tr -d '\r')
encoded_urls=""
idx=0
ok_count=0

while IFS= read -r raw_url || [ -n "${raw_url}" ]; do
  sub_item=$(printf '%s' "${raw_url}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "${sub_item}" ] && continue
  case "${sub_item}" in
    \#*) continue ;;
  esac

  idx=$((idx + 1))
  dest="${SUBCONV_DIR}/cache_sub_raw_${idx}"
  fetch_response=$(curl_direct -w "%{http_code}" -o "${dest}" "${sub_item}")
  fetch_exit_code=$?

  if [ "${fetch_exit_code}" -ne 0 ]; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 订阅 ${idx} 网络错误，退出码 ${fetch_exit_code}"
    continue
  fi
  if [ "${fetch_response}" -ne 200 ]; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 订阅 ${idx} 下载失败，响应码 ${fetch_response}"
    continue
  fi
  if [ ! -s "${dest}" ]; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 订阅 ${idx} 内容为空"
    continue
  fi

  encoded_item=$(jq -rn --arg x "${dest}" '$x|@uri' 2>/dev/null)
  if [ -z "${encoded_item}" ]; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 订阅 ${idx} 路径编码失败"
    continue
  fi

  if [ -z "${encoded_urls}" ]; then
    encoded_urls="${encoded_item}"
  else
    encoded_urls="${encoded_urls}|${encoded_item}"
  fi
  ok_count=$((ok_count + 1))
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅 ${idx} 下载成功 ($(wc -c < "${dest}" | tr -d ' ') bytes)"
done <<EOF
${url_list}
EOF

if [ "${ok_count}" -eq 0 ]; then
  exit_code=1
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error: 全部订阅下载失败，保留现有配置"
  notify "fail" "全部订阅下载失败"
  restore_good_config
  sub_end
fi

# ---------------------------
# 可选规则模板
# ---------------------------
encoded_config_param=""
profile_config_line=""
if [ -n "${config_url}" ]; then
  case "${config_url}" in
    http://*|https://*)
      log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 下载自定义配置..."
      config_response=$(curl_direct -w "%{http_code}" -o "${SUBCONV_DIR}/cache_sub_config.ini" "${config_url}")
      config_exit_code=$?
      if [ "${config_exit_code}" -ne 0 ] || [ "${config_response}" -ne 200 ] || [ ! -s "${SUBCONV_DIR}/cache_sub_config.ini" ]; then
        exit_code=1
        log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error: 自定义配置下载失败"
        notify "fail" "自定义配置下载失败"
        restore_good_config
        sub_end
      fi
      config_path="${SUBCONV_DIR}/cache_sub_config.ini"
      ;;
    *)
      config_path="${config_url}"
      ;;
  esac
  encoded_config_path=$(jq -rn --arg x "${config_path}" '$x|@uri' 2>/dev/null)
  if [ -z "${encoded_config_path}" ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error: 配置文件路径编码失败"
    notify "fail" "配置路径编码失败"
    restore_good_config
    sub_end
  fi
  encoded_config_param="&config=${encoded_config_path}"
  profile_config_line="config=${config_path}"
fi

# 家庭订阅 profile 使用未编码的本地路径
profile_url=""
p=1
while [ "${p}" -le "${idx}" ]; do
  f="${SUBCONV_DIR}/cache_sub_raw_${p}"
  if [ -s "${f}" ]; then
    if [ -z "${profile_url}" ]; then
      profile_url="${f}"
    else
      profile_url="${profile_url}|${f}"
    fi
  fi
  p=$((p + 1))
done

for target in clash surge quanx singbox; do
  {
    echo "[Profile]"
    echo "target=${target}"
    echo "url=${profile_url}"
    echo "emoji=true"
    echo "udp=true"
    if [ -n "${profile_config_line}" ]; then
      echo "${profile_config_line}"
    fi
  } > "${SUBCONV_DIR}/profiles/${target}.ini"
done

# ---------------------------
# 交给 Subconverter 转换
# ---------------------------
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件转换..."
token_q=""
if [ -n "${SUB_TOKEN}" ]; then
  token_q="&token=${SUB_TOKEN}"
fi
sub_response=$(curl -s --max-time 60 -w "%{http_code}" -o /tmp/mihomo_temp.yml \
  "http://127.0.0.1:25500/sub?target=clash&url=${encoded_urls}${encoded_config_param}${token_q}")
sub_exit_code=$?

if [ "${sub_exit_code}" -ne 0 ] || [ "${sub_response}" -ne 200 ] || [ ! -s /tmp/mihomo_temp.yml ]; then
  exit_code=1
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error: 订阅文件转换失败，退出码 ${sub_exit_code} 响应码 ${sub_response:-none}"
  notify "fail" "订阅转换失败"
  restore_good_config
  sub_end
fi

# ---------------------------
# 受管字段 + 去掉与本地冲突的键
# ---------------------------
secret_esc=$(yaml_escape "${SECRET}")
output="mixed-port: ${MIXED_PORT}
allow-lan: ${ALLOW_LAN}
bind-address: \"*\"
external-ui: /root/.config/mihomo/ui
external-ui-url: \"https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip\"
external-controller: 0.0.0.0:${CONTROLLER_PORT}
secret: \"${secret_esc}\"
"

filtered_content=$(awk 'NR>=3 && !(/^[[:space:]]*(mixed-port|allow-lan|bind-address|external-ui|external-ui-url|external-controller|secret):/)' /tmp/mihomo_temp.yml)
output="${output}${filtered_content}
"
printf '%s' "${output}" > /tmp/mihomo_merged.yml

# overlay 深合并，并处理 rules-prepend / rules-append
if [ -f "${OVERLAY_FILE}" ] && [ -s "${OVERLAY_FILE}" ]; then
  if command -v yq >/dev/null 2>&1; then
    if yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      /tmp/mihomo_merged.yml "${OVERLAY_FILE}" > /tmp/mihomo_overlay.yml; then
      yq -i '
        .rules = ((.["rules-prepend"] // []) + (.rules // []) + (.["rules-append"] // [])) |
        del(.["rules-prepend"]) | del(.["rules-append"])
      ' /tmp/mihomo_overlay.yml
      mv /tmp/mihomo_overlay.yml /tmp/mihomo_merged.yml
      log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 已合并 overlay.yaml"
    else
      log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: overlay.yaml 合并失败，沿用转换结果"
    fi
  else
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 未安装 yq，跳过 overlay.yaml"
  fi
fi

# 再次强制受管字段，避免 overlay 覆盖端口和密钥
if command -v yq >/dev/null 2>&1; then
  yq -i "
    .\"mixed-port\" = ${MIXED_PORT} |
    .\"allow-lan\" = ${ALLOW_LAN} |
    .\"bind-address\" = \"*\" |
    .\"external-controller\" = \"0.0.0.0:${CONTROLLER_PORT}\" |
    .secret = \"${secret_esc}\" |
    .\"external-ui\" = \"/root/.config/mihomo/ui\"
  " /tmp/mihomo_merged.yml
fi

cp -f /tmp/mihomo_merged.yml "${CONFIG_FILE}"
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件更新成功"

# ---------------------------
# 热重载；失败则回滚上一份可用配置
# ---------------------------
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载..."
auth_header=""
if [ -n "${SECRET}" ]; then
  auth_header="Authorization: Bearer ${SECRET}"
fi

if [ -n "${auth_header}" ]; then
  reload_response=$(curl -s --max-time 15 -w "%{http_code}" -o /dev/null -X PUT \
    "http://127.0.0.1:${CONTROLLER_PORT}/configs?force=true" \
    -H "Content-Type: application/json" \
    -H "${auth_header}" \
    -d '{"path":"","payload":""}')
else
  reload_response=$(curl -s --max-time 15 -w "%{http_code}" -o /dev/null -X PUT \
    "http://127.0.0.1:${CONTROLLER_PORT}/configs?force=true" \
    -H "Content-Type: application/json" \
    -d '{"path":"","payload":""}')
fi
reload_exit_code=$?

if [ "${reload_exit_code}" -ne 0 ]; then
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: mihomo 服务未启动，跳过热重载（启动后会读取新配置）"
  cp -f "${CONFIG_FILE}" "${GOOD_FILE}"
elif [ "${reload_response}" -ne 204 ] && [ "${reload_response}" -ne 200 ]; then
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 配置重新加载失败，响应码 ${reload_response}，尝试回滚"
  if [ -f "${GOOD_FILE}" ]; then
    cp -f "${GOOD_FILE}" "${CONFIG_FILE}"
    if [ -n "${auth_header}" ]; then
      curl -s --max-time 15 -o /dev/null -X PUT \
        "http://127.0.0.1:${CONTROLLER_PORT}/configs?force=true" \
        -H "Content-Type: application/json" \
        -H "${auth_header}" \
        -d '{"path":"","payload":""}' >/dev/null 2>&1 || true
    fi
    notify "fail" "新配置热重载失败，已回滚"
  fi
else
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载完成"
  cp -f "${CONFIG_FILE}" "${GOOD_FILE}"
fi

sub_end
