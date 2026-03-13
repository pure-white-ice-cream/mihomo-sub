# Mihomo Subconverter Docker Image

[![Docker Build and Publish](https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml)
[![License](https://img.shields.io/github/license/pure-white-ice-cream/mihomo-sub)](LICENSE)
[![Docker Pulls](https://img.shields.io/docker/pulls/purewhiteicecream/mihomo-sub)](https://hub.docker.com/r/purewhiteicecream/mihomo-sub)

本项目提供了一个基于 Docker 的 `mihomo` 核心镜像，集成了 `subconverter` 和 `metacubexd` Web 面板，支持定时更新订阅，旨在提供一个便捷、高效的代理服务部署方案。

## 🚀 特性

- **核心组件**: 预装 `mihomo` 核心，提供强大的代理功能。
- **订阅转换**: 内置 `subconverter`，支持多种订阅格式的转换，确保兼容性。
- **Web 面板**: 集成 `metacubexd`，提供直观的图形用户界面，方便管理和监控。
- **定时更新**: 支持通过 `cron` 表达式配置订阅自动更新，保持代理配置最新。
- **多架构支持**: `linux/amd64`, `linux/arm64` 等多平台架构支持。
- **自动化构建**: 通过 GitHub Actions 自动构建并推送至 Docker Hub。

## 📦 快速开始

### Docker Run

```bash
docker run -d \
  --name mihomo-sub \
  -e TZ=Asia/Shanghai \
  -e sub_url="https://your-subscription-url.com" \
  -e cron="0 */1 * * *" \
  -p 7890:7890 \
  -p 9090:9090 \
  purewhiteicecream/mihomo-sub:latest
```

### Docker Compose

创建一个 `docker-compose.yml` 文件：

```yaml
version: '3.8'
services:
  mihomo:
    image: purewhiteicecream/mihomo-sub:latest
    container_name: mihomo-sub
    volumes:
      - "config:/root/.config/mihomo"
    environment:
      - TZ=Asia/Shanghai
      - sub_url=https://your-subscription-url.com
      # 可选：自定义配置文件的 URL
      # - config_url=https://your-custom-config-url.com
      # 定时更新订阅的 cron 表达式，"0 * * * *" 表示每小时整点；例如 "*/15 * * * *" 表示每 15 分钟
      - cron=0 */1 * * *
    ports:
      - "7890:7890" # 代理 mixed 端口
      - "9090:9090" # Web 面板端口
    restart: unless-stopped

volumes:
  config:
```

## ⚙️ 环境变量

| 变量名       | 描述                                     | 默认值      | 示例                                |
| :----------- | :--------------------------------------- | :---------- | :---------------------------------- |
| `TZ`         | 容器时区                                 | `Asia/Shanghai` | `America/New_York`                  |
| `sub_url`    | 订阅链接，**必填**                       | 无          | `https://your-subscription-url.com` |
| `config_url` | 自定义配置文件的 URL (可选)              | 无          | `https://your-custom-config-url.com`|
| `cron`       | 定时更新订阅的 cron 表达式 (可选)         | 无          | `*/15 * * * *` (每15分钟)           |

## 📂 文件结构

- `/root/.config/mihomo/config.yaml`: `mihomo` 核心的配置文件，由 `sub.sh` 脚本自动生成和更新。
- `/root/.config/mihomo/log.txt`: 订阅更新日志。
- `/root/.config/mihomo/ui`: `metacubexd` Web 面板文件。

## 🏷️ 标签说明

| 标签       | 说明                                     |
| :--------- | :--------------------------------------- |
| `latest`   | 对应 `main` 分支的最新稳定构建           |
| `v*.*.*`   | 对应 Git Tag 的语义化版本                |
| `sha-*`    | 对应每次提交的短哈希，用于精准回溯       |
| `main`     | 对应 `main` 分支的最新代码               |

## 📄 许可证

本项目遵循 [MIT License](LICENSE)。
