#!/bin/sh

# ---------------------------
# 路径与变量
# ---------------------------
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
LOG_FILE="${CONFIG_DIR}/log.txt"
# 放到 subconverter 工作目录，确保可按本地路径读取
SUB_RAW_FILE="/subconverter/cache_sub_raw"
SUB_CONFIG_FILE="/subconverter/cache_sub_config.ini"
# 使用常见客户端 UA，降低被 Cloudflare / 订阅站拦截的概率
SUB_UA="clash.meta"

# 确保目录存在
mkdir -p "${CONFIG_DIR}"

output=""     # 保存生成的 config 内容
log=""        # 保存日志内容
exit_code=0   # 失败时非 0，便于启动脚本识别

# 使用真正的换行符，避免 printf %b 在某些环境下的兼容性问题
output="mixed-port: 7890
external-ui: /root/.config/mihomo/ui
external-ui-url: \"https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip\"
external-controller: :9090
"

# ---------------------------
# 追加一条日志（同时输出到控制台和缓冲区）
# ---------------------------
log_msg() {
    msg="$1"
    printf "%b\n" "${msg}"
    log="${log}${msg}\n"
}

# ---------------------------
# 输出日志并退出
# ---------------------------
sub_end() {
    printf "%b\n" "${log}" >> "${LOG_FILE}"
    exit "${exit_code}"
}

# 直连下载（清除代理环境变量，避免走未就绪的代理）
curl_direct() {
    env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY -u all_proxy -u ALL_PROXY \
        curl -sL --max-time 30 -A "${SUB_UA}" "$@"
}

# ---------------------------
# 订阅更新
# ---------------------------
if [ -z "${sub_url}" ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: sub_url 变量未设置"
    sub_end
fi

# 先由 curl 下载订阅，避免 Subconverter 自带 SubConverter-* 请求头被 Cloudflare 拦截
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 下载订阅文件..."
fetch_response=$(curl_direct -w "%{http_code}" -o "${SUB_RAW_FILE}" "${sub_url}")
fetch_exit_code=$?

if [ "${fetch_exit_code}" -ne 0 ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅下载网络错误，退出码: ${fetch_exit_code}"
    sub_end
elif [ "${fetch_response}" -ne 200 ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅下载失败，响应码: ${fetch_response}"
    sub_end
elif [ ! -s "${SUB_RAW_FILE}" ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅下载内容为空"
    sub_end
fi
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅下载成功 ($(wc -c < "${SUB_RAW_FILE}" | tr -d ' ') bytes)"

encoded_sub_path=$(jq -rn --arg x "${SUB_RAW_FILE}" '$x|@uri' 2>/dev/null)
if [ -z "${encoded_sub_path}" ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅文件路径编码失败"
    sub_end
fi

encoded_config_param=""
if [ -n "${config_url}" ]; then
    case "${config_url}" in
        http://*|https://*)
            log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 下载自定义配置..."
            config_response=$(curl_direct -w "%{http_code}" -o "${SUB_CONFIG_FILE}" "${config_url}")
            config_exit_code=$?
            if [ "${config_exit_code}" -ne 0 ]; then
                exit_code=1
                log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 配置下载网络错误，退出码: ${config_exit_code}"
                sub_end
            elif [ "${config_response}" -ne 200 ]; then
                exit_code=1
                log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 配置下载失败，响应码: ${config_response}"
                sub_end
            elif [ ! -s "${SUB_CONFIG_FILE}" ]; then
                exit_code=1
                log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 配置下载内容为空"
                sub_end
            fi
            config_path="${SUB_CONFIG_FILE}"
            ;;
        *)
            config_path="${config_url}"
            ;;
    esac
    encoded_config_path=$(jq -rn --arg x "${config_path}" '$x|@uri' 2>/dev/null)
    if [ -z "${encoded_config_path}" ]; then
        exit_code=1
        log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 配置文件路径编码失败"
        sub_end
    fi
    encoded_config_param="&config=${encoded_config_path}"
fi

log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件转换..."
# 将本地文件交给 Subconverter 转换，不再让它直接请求远程订阅
sub_response=$(curl -s --max-time 30 -w "%{http_code}" -o /tmp/mihomo_temp.yml "http://127.0.0.1:25500/sub?target=clash&url=${encoded_sub_path}${encoded_config_param}")
sub_exit_code=$?

if [ "${sub_exit_code}" -ne 0 ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 转换请求网络错误，退出码: ${sub_exit_code}"
    sub_end
elif [ "${sub_response}" -ne 200 ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅文件转换失败，响应码: ${sub_response}"
    sub_end
elif [ ! -s /tmp/mihomo_temp.yml ]; then
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 转换结果为空"
    sub_end
fi

# ---------------------------
# 去掉与本地冲突后写入 config
# ---------------------------
if [ -f /tmp/mihomo_temp.yml ]; then
    filtered_content=$(awk 'NR>=3 && !(/^[[:space:]]*mixed-port:/ || /^[[:space:]]*external-ui:/ || /^[[:space:]]*external-ui-url:/ || /^[[:space:]]*external-controller:/)' /tmp/mihomo_temp.yml)
    output="${output}${filtered_content}\n"
    printf "%b" "${output}" > "${CONFIG_FILE}"
else
    exit_code=1
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 临时文件不存在"
    sub_end
fi
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件更新成功 ✅"

# ---------------------------
# 配置重新加载（首次启动时 mihomo 可能尚未运行，仅告警）
# ---------------------------
log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载..."
reload_response=$(curl -s --max-time 15 -w "%{http_code}" -o /dev/null -X PUT "http://127.0.0.1:9090/configs?force=true" \
    -H "Content-Type: application/json" \
    -d '{"path":"","payload":""}')
reload_exit_code=$?

if [ "${reload_exit_code}" -ne 0 ]; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning⚠️: mihomo 服务未启动，跳过热重载（启动后会读取新配置）"
elif [ "${reload_response}" -ne 204 ]; then
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] Warning⚠️: 配置重新加载失败，响应码: ${reload_response}"
else
    log_msg "[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载完成 ✅"
fi

sub_end
