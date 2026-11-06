#!/bin/sh

# ---------------------------
# 路径与变量
# ---------------------------
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
GOOD_FILE="${CONFIG_DIR}/config.yaml.good"
OVERLAY_FILE="${CONFIG_DIR}/overlay.yaml"
OVERLAY_SCRIPT="${CONFIG_DIR}/overlay.js"
LOG_FILE="${CONFIG_DIR}/log.txt"
SECRET_FILE="${CONFIG_DIR}/.secret"
SUBCONV_DIR="/subconverter"
SUB_UA="${SUB_UA:-clash.meta}"

. /usr/local/lib/mihomo-sub/runtime-config.sh

MIXED_PORT="${MIXED_PORT:-7890}"
CONTROLLER_PORT="${CONTROLLER_PORT:-9090}"
ALLOW_LAN="${ALLOW_LAN:-true}"

mkdir -p "${CONFIG_DIR}"

case "${SECRET}" in
  off|OFF|none|NONE|false|FALSE|disable|DISABLE|disabled|DISABLED)
    SECRET=""
    ;;
  "")
    if [ -f "${SECRET_FILE}" ]; then
      SECRET=$(tr -d '[:space:]' < "${SECRET_FILE}")
    fi
    ;;
esac
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

fail_config_update() {
  exit_code=1
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error: $1，保留当前配置"
  notify "fail" "$1"
  sub_end
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

curl_direct() {
  env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
    curl -sL --retry 3 --retry-delay 2 --max-time 30 -A "${SUB_UA}" "$@"
}

restore_good_config() {
  if [ ! -s "${CONFIG_FILE}" ] && [ -s "${GOOD_FILE}" ]; then
    cp -f "${GOOD_FILE}" "${CONFIG_FILE}"
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 已恢复上一份可用配置"
  fi
}

reload_config() {
  curl --noproxy '*' -s --max-time 15 -w "%{http_code}" -o /dev/null -X PUT \
    "http://127.0.0.1:${CONTROLLER_PORT}/configs?force=true" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${SECRET}" \
    -d '{"path":"","payload":""}'
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

# 启动、定时和手动更新共用订阅缓存，同一时间只允许一次更新。
exec 9>>"${CONFIG_DIR}/.sub-update.lock"
flock -x 9 || fail_config_update "获取订阅更新锁失败"

# 临时目录和正式配置位于同一卷，校验通过后可原子替换。
work_dir=$(mktemp -d "${CONFIG_DIR}/.sub-update.XXXXXX") || fail_config_update "创建临时目录失败"
trap 'rm -rf -- "${work_dir}"' EXIT
converted_file="${work_dir}/converted.yaml"
candidate_file="${work_dir}/config.yaml"

script_enabled=0
if [ -e "${OVERLAY_SCRIPT}" ] || [ -L "${OVERLAY_SCRIPT}" ]; then
  [ -f "${OVERLAY_SCRIPT}" ] || fail_config_update "overlay.js 必须是普通文件"
  script_enabled=1
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
sub_response=$(curl --noproxy '*' -s --max-time 60 -w "%{http_code}" -o "${converted_file}" \
  "http://127.0.0.1:25500/sub?target=clash&url=${encoded_urls}${encoded_config_param}${token_q}")
sub_exit_code=$?

if [ "${sub_exit_code}" -ne 0 ] || [ "${sub_response}" -ne 200 ] || [ ! -s "${converted_file}" ]; then
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
external-ui: ${MIHOMO_UI_DIR}
external-ui-url: \"${MIHOMO_UI_URL}\"
external-controller: 0.0.0.0:${CONTROLLER_PORT}
secret: \"${secret_esc}\"
"

filtered_content=$(awk 'NR>=3 && !(/^[[:space:]]*(mixed-port|allow-lan|bind-address|external-ui|external-ui-url|external-controller|secret):/)' "${converted_file}") ||
  fail_config_update "读取转换结果失败"
output="${output}${filtered_content}
"
printf '%s' "${output}" > "${candidate_file}" || fail_config_update "写入候选配置失败"

# overlay 深合并，并处理 rules-prepend / rules-append
if [ -f "${OVERLAY_FILE}" ] && [ -s "${OVERLAY_FILE}" ]; then
  merged_file="${work_dir}/overlay.yaml"
  if ! command -v yq >/dev/null 2>&1; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 未安装 yq，跳过 overlay.yaml"
  elif yq eval-all -e 'select(fileIndex == 0) * select(fileIndex == 1)' \
    "${candidate_file}" "${OVERLAY_FILE}" > "${merged_file}" &&
    yq -i -e '
      .rules = ((.["rules-prepend"] // []) + (.rules // []) + (.["rules-append"] // [])) |
      del(.["rules-prepend"]) | del(.["rules-append"])
    ' "${merged_file}" &&
    mv -f "${merged_file}" "${candidate_file}"; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 已合并 overlay.yaml"
  elif [ "${script_enabled}" -eq 1 ]; then
    fail_config_update "overlay.yaml 合并失败"
  else
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: overlay.yaml 合并失败，沿用转换结果"
  fi
fi

# 脚本仅接收配置对象，面板密钥在脚本执行后由容器写入。
if [ "${script_enabled}" -eq 1 ]; then
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 执行 overlay.js..."
  yq -e -o=json 'select(kind == "map") | explode(.) | del(.secret)' "${candidate_file}" \
    > "${work_dir}/input.json" || fail_config_update "overlay.js 输入转换失败"
  timeout -s KILL 5 mihomo-overlay-js "${OVERLAY_SCRIPT}" \
    < "${work_dir}/input.json" > "${work_dir}/output.json" ||
    fail_config_update "overlay.js 执行失败或超时"
  yq -e -p=json -o=yaml 'select(kind == "map")' "${work_dir}/output.json" \
    > "${candidate_file}" || fail_config_update "overlay.js 输出转换失败"
fi

# 覆写完成后再次写入容器管理的字段。
apply_runtime_fields "${candidate_file}" || fail_config_update "写入受管字段失败"

if [ "${script_enabled}" -eq 1 ]; then
  /mihomo -t -d "${CONFIG_DIR}" -f "${candidate_file}" ||
    fail_config_update "overlay.js 生成的 Mihomo 配置校验失败"
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] overlay.js 覆写通过配置校验"
fi

previous_file="${work_dir}/previous.yaml"
if [ -s "${CONFIG_FILE}" ]; then
  cp -p "${CONFIG_FILE}" "${previous_file}" || fail_config_update "保存当前配置失败"
fi
mv -f "${candidate_file}" "${CONFIG_FILE}" || fail_config_update "替换运行配置失败"
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件更新成功"

# ---------------------------
# 热重载；失败则回滚上一份可用配置
# ---------------------------
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载..."
reload_response=$(reload_config)
reload_exit_code=$?

if [ "${reload_exit_code}" -ne 0 ]; then
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: mihomo 服务未启动，跳过热重载（启动后会读取新配置）"
  cp -f "${CONFIG_FILE}" "${GOOD_FILE}"
elif [ "${reload_response}" -ne 204 ] && [ "${reload_response}" -ne 200 ]; then
  exit_code=1
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning: 配置重新加载失败，响应码 ${reload_response}，尝试回滚"
  if [ -s "${previous_file}" ] && mv -f "${previous_file}" "${CONFIG_FILE}"; then
    reload_config >/dev/null 2>&1 || true
    notify "fail" "新配置热重载失败，已回滚"
  else
    notify "fail" "新配置热重载失败，无法恢复原配置"
  fi
else
  log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载完成"
  cp -f "${CONFIG_FILE}" "${GOOD_FILE}"
fi

sub_end
