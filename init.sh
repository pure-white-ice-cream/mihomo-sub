#!/bin/sh
# Mihomo + Subconverter 容器启动脚本

SUB_SCRIPT="/usr/local/bin/sub.sh"
LOG_FILE="/root/.config/mihomo/log.txt"

echo "=========================================="
echo "  Mihomo + Subconverter 容器正在启动..."
echo "=========================================="

# 后台启动 subconverter
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [1/4] 启动 Subconverter 服务..."
/subconverter/subconverter &
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")]       Subconverter 已后台运行"

# 配置 crontab：按 cron 定时执行订阅脚本（cron 为空则不创建定时任务）
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [2/4] 配置定时任务 (cron: ${cron:-未设置})..."
if [ -n "$cron" ]; then
	echo "${cron} $SUB_SCRIPT >> $LOG_FILE 2>&1" > /etc/crontabs/root
	crond -d 8 &
	echo "[$(date +"%Y-%m-%d %H:%M:%S %z")]       crond 已后台运行，将按计划更新订阅"
else
	echo "[$(date +"%Y-%m-%d %H:%M:%S %z")]       cron 未设置，跳过定时任务"
fi

# 等待服务就绪后执行一次订阅转换
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [3/4] 等待服务就绪并执行首次订阅转换..."
sleep 5
"$SUB_SCRIPT" && echo "[$(date +"%Y-%m-%d %H:%M:%S %z")]       首次订阅转换完成" || echo "[$(date +"%Y-%m-%d %H:%M:%S %z")]       订阅转换执行完毕（请检查日志: $LOG_FILE）"

# 前台运行 mihomo（容器主进程）
echo "[$(date +"%Y-%m-%d %H:%M:%S %z")] [4/4] 启动 Mihomo（前台运行，日志见下方）..."
echo "=========================================="
echo "  提示: 按 Ctrl+C 可停止容器"
echo "=========================================="
exec /mihomo
