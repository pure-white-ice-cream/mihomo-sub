#!/bin/sh

# ---------------------------
# 路径与变量
# ---------------------------
CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
LOG_FILE="${CONFIG_DIR}/log.txt"

output=""     # 保存生成的 config 内容
log=""        # 保存日志内容

output="${output}mixed-port: 7890\n"
output="${output}external-ui: /root/.config/mihomo/ui\n"
output="${output}external-controller: :9090\n"

# ---------------------------
# 输出日志并退出
# ---------------------------
sub_end() {
    log="${log}\n"
    # 使用 printf %b 让 \n \t 生效
    printf "%b" "${log}" >> "${LOG_FILE}"
    exit 0
}

# ---------------------------
# 订阅更新
# ---------------------------
if [ -z "${sub_url}" ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: sub_url 变量未设置\n\t"
    sub_end
fi

encoded_sub_url=$(jq -rn --arg x "${sub_url}" \'$x|@uri\' 2>/dev/null)
if [ -z "${encoded_sub_url}" ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: 订阅文件 URL 编码失败\n\t"
    sub_end
fi

encoded_config_param=""
if [ -n "${config_url}" ]; then
    encoded_config_url=$(jq -rn --arg x "${config_url}" \'$x|@uri\' 2>/dev/null)
    if [ -z "${encoded_config_url}" ]; then
        log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: 配置文件 URL 编码失败\n\t"
        sub_end
    fi
    encoded_config_param="&config=${encoded_config_url}"
fi

log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] 订阅文件更新...\n\t"
sub_response=$(curl -s --max-time 15 -w "%{http_code}" -o /tmp/mihomo_temp.yml "http://127.0.0.1:25500/sub?target=clash&url=${encoded_sub_url}${encoded_config_param}")
sub_exit_code=$?

if [ "${sub_exit_code}" -ne 0 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: 网络错误，退出码: ${sub_exit_code}\n\t"
    sub_end
elif [ "${sub_response}" -ne 200 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: 订阅文件更新失败，响应码: ${sub_response}\n\t"
    sub_end
fi

# ---------------------------
# 去掉与本地冲突后写入 config
# ---------------------------
if [ -f /tmp/mihomo_temp.yml ]; then
    output="${output}$(awk \'NR>=3 && !(/^[[:space:]]*mixed-port:/ || /^[[:space:]]*external-ui:/ || /^[[:space:]]*external-controller:/)\' /tmp/mihomo_temp.yml)\n"
    printf "%b" "${output}" > "${CONFIG_FILE}"
else
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: 临时文件不存在\n\t"
    sub_end
fi
log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] 订阅文件更新成功 ✅\n\t"

# ---------------------------
# 配置重新加载
# ---------------------------
log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] 配置重新加载...\n\t"
reload_response=$(curl -s --max-time 15 -w "%{http_code}" -o /dev/null -X PUT "http://127.0.0.1:9090/configs?force=true" -H "Content-Type: application/json" -d \'{"path":"","payload":""}\
')
reload_exit_code=$?

if [ "${reload_exit_code}" -ne 0 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Warning⚠️: mihomo 服务未启动( 第一次订阅出现此警告是正常现象 )，退出码: ${reload_exit_code}\n\t"
    sub_end
elif [ "${reload_response}" -ne 204 ]; then
    log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] Error❌️: 配置重新加载失败，响应码: ${reload_response}\n\t"
    sub_end
fi

log="${log}[$(date +"%Y-%m-%d %H:%M:%S %z")] 配置重新加载完成 ✅\n\t"
sub_end
