#!/bin/sh

# ---------------------------
# 路径与变量
# ---------------------------
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
LOG_FILE="${CONFIG_DIR}/log.txt"

# 确保目录存在
mkdir -p "${CONFIG_DIR}"

output=""     # 保存生成的 config 内容
log=""        # 保存日志内容

# 使用真正的换行符，避免 printf %b 在某些环境下的兼容性问题
output="mixed-port: 7890
external-ui: /root/.config/mihomo/ui
external-controller: :9090
"

# ---------------------------
# 输出日志并退出
# ---------------------------
sub_end() {
    # 使用 printf 直接输出到日志文件
    printf "%b\n" "${log}" >> "${LOG_FILE}"
    exit 0
}

# ---------------------------
# 订阅更新
# ---------------------------
if [ -z "${sub_url}" ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: sub_url 变量未设置\n"
    sub_end
fi

# 修正 jq 调用：不要在单引号里用 \'，直接用单引号包裹 jq 表达式
encoded_sub_url=$(jq -rn --arg x "${sub_url}" '$x|@uri' 2>/dev/null)
if [ -z "${encoded_sub_url}" ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅文件 URL 编码失败\n"
    sub_end
fi

encoded_config_param=""
if [ -n "${config_url}" ]; then
    encoded_config_url=$(jq -rn --arg x "${config_url}" '$x|@uri' 2>/dev/null)
    if [ -z "${encoded_config_url}" ]; then
        log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 配置文件 URL 编码失败\n"
        sub_end
    fi
    encoded_config_param="&config=${encoded_config_url}"
fi

log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件更新...\n"
# 注意：curl 的输出直接捕获状态码
sub_response=$(curl -s --max-time 15 -w "%{http_code}" -o /tmp/mihomo_temp.yml "http://127.0.0.1:25500/sub?target=clash&url=${encoded_sub_url}${encoded_config_param}")
sub_exit_code=$?

if [ "${sub_exit_code}" -ne 0 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 网络错误，退出码: ${sub_exit_code}\n"
    sub_end
elif [ "${sub_response}" -ne 200 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 订阅文件更新失败，响应码: ${sub_response}\n"
    sub_end
fi

# ---------------------------
# 去掉与本地冲突后写入 config
# ---------------------------
if [ -f /tmp/mihomo_temp.yml ]; then
    # 修正 awk 内部引用，去掉多余的反斜杠
    filtered_content=$(awk 'NR>=3 && !(/^[[:space:]]*mixed-port:/ || /^[[:space:]]*external-ui:/ || /^[[:space:]]*external-controller:/)' /tmp/mihomo_temp.yml)
    output="${output}${filtered_content}\n"
    printf "%b" "${output}" > "${CONFIG_FILE}"
else
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 临时文件不存在\n"
    sub_end
fi
log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] 订阅文件更新成功 ✅\n"

# ---------------------------
# 配置重新加载
# ---------------------------
log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载...\n"
# 修正 JSON 负载的引号处理
reload_response=$(curl -s --max-time 15 -w "%{http_code}" -o /dev/null -X PUT "http://127.0.0.1:9090/configs?force=true" \
    -H "Content-Type: application/json" \
    -d '{"path":"","payload":""}')
reload_exit_code=$?

if [ "${reload_exit_code}" -ne 0 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Warning⚠️: mihomo 服务未启动，退出码: ${reload_exit_code}\n"
    sub_end
elif [ "${reload_response}" -ne 204 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] Error❌️: 配置重新加载失败，响应码: ${reload_response}\n"
    sub_end
fi

log="${log}[$(date +"%Y-%m-%d %H:%M:%S")] 配置重新加载完成 ✅\n"
sub_end