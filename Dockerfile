FROM --platform=$BUILDPLATFORM golang:1.26-alpine AS overlay-builder
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY overlay-js/go.mod overlay-js/go.sum ./
RUN go mod download
COPY overlay-js/main.go ./
RUN CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" GOARM=7 \
    go build -mod=readonly -trimpath -ldflags="-s -w" -o /mihomo-overlay-js .

FROM metacubex/mihomo:v1.19.33

# 安装依赖
RUN apk add --no-cache jq curl bash unzip flock

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

# 面板放在数据卷外，容器重建后直接使用镜像内的版本。
ARG ZASHBOARD_VERSION=v3.30.0
ENV MIHOMO_UI_DIR=/usr/local/share/mihomo/ui \
    MIHOMO_UI_URL=https://github.com/Zephyruso/zashboard/releases/download/${ZASHBOARD_VERSION}/dist-no-fonts.zip
ENV SAFE_PATHS=${MIHOMO_UI_DIR}
RUN wget -O /tmp/zashboard.zip "${MIHOMO_UI_URL}" && \
    mkdir -p /tmp/zashboard "${MIHOMO_UI_DIR}" && \
    unzip -q /tmp/zashboard.zip -d /tmp/zashboard && \
    mv /tmp/zashboard/dist/* "${MIHOMO_UI_DIR}/" && \
    test -s "${MIHOMO_UI_DIR}/index.html" && \
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
COPY runtime-config.sh /usr/local/lib/mihomo-sub/runtime-config.sh
COPY --from=overlay-builder /mihomo-overlay-js /usr/local/bin/mihomo-overlay-js
RUN chmod +x /usr/local/bin/sub.sh /usr/local/bin/init.sh /usr/local/bin/healthcheck.sh

HEALTHCHECK --interval=30s --timeout=8s --start-period=40s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/init.sh"]
