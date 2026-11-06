# 用户也可以为本地规则配置 SAFE_PATHS，保留这些路径。
case ":${SAFE_PATHS:-}:" in
  *":${MIHOMO_UI_DIR}:"*) ;;
  *) export SAFE_PATHS="${SAFE_PATHS:+${SAFE_PATHS}:}${MIHOMO_UI_DIR}" ;;
esac

# 启动和订阅更新使用同一组受管字段。
apply_runtime_fields() {
  MIXED_PORT="${MIXED_PORT}" ALLOW_LAN="${ALLOW_LAN}" CONTROLLER_PORT="${CONTROLLER_PORT}" SECRET="${SECRET}" \
    yq -i -e '
      select(kind == "map") |
      ."mixed-port" = env(MIXED_PORT) |
      ."allow-lan" = env(ALLOW_LAN) |
      ."bind-address" = "*" |
      ."external-controller" = ("0.0.0.0:" + strenv(CONTROLLER_PORT)) |
      .secret = strenv(SECRET) |
      ."external-ui" = strenv(MIHOMO_UI_DIR) |
      ."external-ui-url" = (
        (."external-ui-url" | select(. != "" and . != "https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip")) //
        strenv(MIHOMO_UI_URL)
      )
    ' "$1"
}
