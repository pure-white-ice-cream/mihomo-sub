FROM metacubex/mihomo:v1.19.29

# 安装依赖
RUN apk add --no-cache jq curl bash unzip

# 安装 yq，用于 overlay.yaml 合并
ARG TARGETARCH
ARG TARGETVARIANT
RUN case "${TARGETARCH}${TARGETVARIANT}" in \
      "arm64") YQ_BIN="yq_linux_arm64" ;; \
      "armv7") YQ_BIN="yq_linux_arm" ;; \
      "386") YQ_BIN="yq_linux_386" ;; \
      "amd64"|*) YQ_BIN="yq_linux_amd64" ;; \
    esac && \
    wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/v4.44.3/${YQ_BIN}" && \
    chmod +x /usr/local/bin/yq

# 安装 Zashboard Web UI
RUN wget -O /tmp/zashboard.zip https://github.com/Zephyruso/zashboard/releases/download/v3.16.1/dist.zip && \
    mkdir -p /tmp/zashboard /root/.config/mihomo/ui && \
    unzip -q /tmp/zashboard.zip -d /tmp/zashboard && \
    mv /tmp/zashboard/dist/* /root/.config/mihomo/ui/ && \
    rm -rf /tmp/zashboard.zip /tmp/zashboard

# 安装 Subconverter
RUN case "${TARGETARCH}${TARGETVARIANT}" in \
      "arm64") \
        SUBCONV_FILE="subconverter_aarch64.tar.gz" ;; \
      "armv7") \
        SUBCONV_FILE="subconverter_armv7.tar.gz" ;; \
      "386") \
        SUBCONV_FILE="subconverter_linux32.tar.gz" ;; \
      "amd64"|*) \
        SUBCONV_FILE="subconverter_linux64.tar.gz" ;; \
    esac && \
    wget -O /tmp/subconverter.tar.gz https://github.com/MetaCubeX/subconverter/releases/download/v0.9.2/${SUBCONV_FILE} && \
    tar -xzf /tmp/subconverter.tar.gz -C / && \
    rm -rf /tmp/subconverter.tar.gz

# 写入最小默认配置（正式字段由 sub.sh 在启动时生成）
RUN printf '%s\n' \
    'mixed-port: 7890' \
    'allow-lan: true' \
    'external-ui: /root/.config/mihomo/ui' \
    'external-ui-url: "https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip"' \
    'external-controller: 0.0.0.0:9090' \
    > /root/.config/mihomo/config.yaml

ENV TZ=Asia/Shanghai \
    sub_url="" \
    config_url="" \
    cron="0 4 * * *" \
    SECRET="" \
    SUB_TOKEN="" \
    ALLOW_LAN=true \
    MIXED_PORT=7890 \
    CONTROLLER_PORT=9090 \
    NOTIFY_WEBHOOK="" \
    SUB_UA=clash.meta

EXPOSE 7890 9090 25500

LABEL org.opencontainers.image.title="mihomo-sub" \
      org.opencontainers.image.description="Mihomo + Subconverter + Zashboard, with scheduled subscription updates" \
      org.opencontainers.image.source="https://github.com/pure-white-ice-cream/mihomo-sub" \
      org.opencontainers.image.licenses="MIT"

COPY sub.sh /usr/local/bin/sub.sh
COPY init.sh /usr/local/bin/init.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/sub.sh /usr/local/bin/init.sh /usr/local/bin/healthcheck.sh

HEALTHCHECK --interval=30s --timeout=8s --start-period=40s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/init.sh"]
