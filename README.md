# mihomo-sub

- `docker` 部署的 `mihomo` 核心, 每小时更新和转换订阅

## 源码和仓库地址
- 源码: `https://github.com/pure-white-ice-cream/mihomo-sub`
- `Docker Hub`: `https://hub.docker.com/r/purewhiteicecream/mihomo-sub`

## 内置工具
- `mihomo`
- Web 面板 `metacubexd`
- 本地订阅转换 `subconverter`
- 定时更新订阅的脚本 `sub.sh`

## 部署示例
``` yml
services:
  mihomo:
    image: purewhiteicecream/mihomo-sub:latest
    container_name: mihomo-sub
    environment:
      - "TZ=Asia/Shanghai"
      - "sub_url=https://这里换成你的订阅地址"
    ports:
     - "7890:7890"
     - "9090:9090"
```

## 服务端口
- 代理 `mixed` 端口: `7980`
- Web 面板: `http://127.0.0.1:9090/ui`

## 关键文件
- `/root/.config/mihomo/config.yaml`: `mihomo` 核心的配置文件, 每小时自动更新
- `/root/.config/mihomo/log.txt`: 每小时更新订阅的日志

## 常见问题
第一次部署的时候不要挂载卷到系统目录, 就像 `nginx` 一样
```yaml
    volumes:
      - /opt/mihomo-sub:/root/.config/mihomo
```