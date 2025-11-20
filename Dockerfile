FROM metacubex/mihomo:v1.19.15

RUN apk add --no-cache jq curl

RUN wget -O /tmp/metacubexd.tgz https://github.com/MetaCubeX/metacubexd/releases/download/v1.195.0/compressed-dist.tgz && \
    mkdir -p /root/.config/mihomo/ui && \
    tar -xzf /tmp/metacubexd.tgz -C /root/.config/mihomo/ui && \
    rm -rf /tmp/metacubexd.tgz

# 使用 buildx 自动传递的架构参数
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
    wget -O /tmp/subconverter.tar.gz https://github.com/tindy2013/subconverter/releases/download/v0.9.0/${SUBCONV_FILE} && \
    tar -xzf /tmp/subconverter.tar.gz -C / && \
    rm -rf /tmp/subconverter.tar.gz

RUN echo 'mixed-port: 7890' >> /root/.config/mihomo/config.yaml && \
    echo 'external-ui: /root/.config/mihomo/ui' >> /root/.config/mihomo/config.yaml && \
    echo 'allow-lan: true' >> /root/.config/mihomo/config.yaml && \
    echo 'external-controller: :9090' >> /root/.config/mihomo/config.yaml

ENV sub_url="" \
config_url=""

EXPOSE 7890 9090

# 创建启动脚本
RUN echo '#!/bin/sh' > /mihomo_init.sh && \
    echo '/mihomo &' >> /mihomo_init.sh && \
    echo '/subconverter/subconverter &' >> /mihomo_init.sh && \
    echo 'sleep 5' >> /mihomo_init.sh && \
    echo '/etc/periodic/hourly/sub.sh' >> /mihomo_init.sh && \
    echo 'exec crond -f -d 8' >> /mihomo_init.sh && \
    chmod +x /mihomo_init.sh

# 15min    daily    hourly   monthly  weekly
COPY sub.sh /etc/periodic/hourly/sub.sh
RUN chmod +x /etc/periodic/hourly/sub.sh

ENTRYPOINT ["/mihomo_init.sh"]