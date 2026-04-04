FROM metacubex/mihomo:v1.19.22

# 安装依赖
RUN apk add --no-cache jq curl bash

# 安装 Metacubexd Web UI
RUN wget -O /tmp/metacubexd.tgz https://github.com/MetaCubeX/metacubexd/releases/download/v1.244.2/compressed-dist.tgz && \
    mkdir -p /root/.config/mihomo/ui && \
    tar -xzf /tmp/metacubexd.tgz -C /root/.config/mihomo/ui && \
    rm -rf /tmp/metacubexd.tgz

# 安装 Subconverter
ARG TARGETARCH
ARG TARGETVARIANT
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

# 写入默认配置
RUN echo 'mixed-port: 7890' >> /root/.config/mihomo/config.yaml && \
    echo 'external-ui: /root/.config/mihomo/ui' >> /root/.config/mihomo/config.yaml && \
    echo 'allow-lan: true' >> /root/.config/mihomo/config.yaml && \
    echo 'external-controller: :9090' >> /root/.config/mihomo/config.yaml

ENV sub_url="" \
    config_url="" \
    cron=""

EXPOSE 7890 9090

COPY sub.sh /usr/local/bin/sub.sh
COPY init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/sub.sh /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]
