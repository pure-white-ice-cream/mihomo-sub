<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="mihomo-sub">
</p>

<h1 align="center">mihomo-sub</h1>

<p align="center">
  NAS / 软路由上一键部署的家庭 Mihomo 网关：订阅转换、定时更新、Web 面板，并可给家里其他设备提供已转换订阅。
</p>

<p align="center">
  <a href="README.en.md">English</a>
</p>

[![Docker Build and Publish](https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml)
[![Version](https://img.shields.io/docker/v/purewhiteicecream/mihomo-sub?sort=semver&label=version)](VERSION)
[![Docker Pulls](https://img.shields.io/docker/pulls/purewhiteicecream/mihomo-sub)](https://hub.docker.com/r/purewhiteicecream/mihomo-sub)
[![License](https://img.shields.io/github/license/pure-white-ice-cream/mihomo-sub)](LICENSE)

当前版本以 [`VERSION`](VERSION) 为准。镜像同时发布到 Docker Hub 与 GHCR：

- `purewhiteicecream/mihomo-sub`
- `ghcr.io/pure-white-ice-cream/mihomo-sub`

## 适合谁 / 不适合谁

**适合：** 有自己的订阅链接，想在 NAS、软路由或家用 Linux 上一容器跑起来；局域网设备走 mixed 端口；手机再导入同一套转换结果。

**不适合：** 当公开订阅站或公开转换 SaaS；把 7890/9090/25500 直接映射到公网；用本镜像分发他人节点。

## 特性

- Mihomo 内核 + Subconverter + Zashboard
- 定时更新订阅，失败保留上一份可用配置
- 多订阅合并（`sub_url` 用 `|` 分隔）
- `overlay.yaml` 保留自定义 DNS / 规则 / TUN
- 面板 API 密钥（未设置则首次启动生成）
- 可选家庭订阅出口（clash / surge / quanx / sing-box）
- `linux/amd64` `linux/arm64` `linux/arm/v7` `linux/386`

## 快速开始

```bash
cp .env.example .env
# 编辑 .env，至少填写 sub_url
docker compose up -d
```

或：

```bash
docker run -d \
  --name mihomo-sub \
  -e TZ=Asia/Shanghai \
  -e sub_url="https://your-subscription-url.com" \
  -e cron="0 4 * * *" \
  -p 7890:7890 \
  -p 9090:9090 \
  -v mihomo-data:/root/.config/mihomo \
  purewhiteicecream/mihomo-sub:latest
```

国内若拉 Docker Hub 不稳定，可改用：

```bash
docker pull ghcr.io/pure-white-ice-cream/mihomo-sub:latest
```

1Panel / CasaOS / Portainer 可导入 [`deploy/portainer-stack.yml`](deploy/portainer-stack.yml)。

## 启动后

1. 看容器日志，记下 **API 密钥** 和 **订阅令牌**（未在 `.env` 里指定时由首次启动生成，之后写在数据卷里）。
2. 打开面板：`http://<主机IP>:9090/ui`，在设置里填入同一密钥。
3. 系统 / 浏览器代理填 `HTTP/SOCKS`：`<主机IP>:7890`。
4. 不要把 7890、9090、25500 直接暴露到公网。

常见失败：

| 现象 | 处理 |
| --- | --- |
| 订阅 403 / 空内容 | 检查链接、更新间隔；默认每天 4:00，过频容易被封 |
| 面板打不开 | 确认映射了 9090，并用日志里的密钥 |
| 局域网连不上代理 | `ALLOW_LAN=true`（默认已是） |
| 更新后自定义规则消失 | 把规则放到 `overlay.yaml` 再挂载 |

## 环境变量

| 变量 | 说明 | 默认 |
| --- | --- | --- |
| `TZ` | 时区 | `Asia/Shanghai` |
| `sub_url` | 订阅链接，多条用 `\|` 分隔，**必填** | 无 |
| `config_url` | Subconverter 外部规则模板 | 无 |
| `cron` | 更新计划；`off` 关闭定时 | `0 4 * * *` |
| `SECRET` | 面板 / Clash API 密钥，留空则生成 | 随机 |
| `ALLOW_LAN` | 是否允许局域网访问代理端口 | `true` |
| `MIXED_PORT` | mixed 端口 | `7890` |
| `CONTROLLER_PORT` | 面板端口 | `9090` |
| `NOTIFY_WEBHOOK` | 失败时 POST `{"status","message"}` | 无 |
| `SUB_TOKEN` | 家庭订阅令牌，留空则生成 | 随机 |
| `SUB_UA` | 拉取订阅时的 User-Agent | `clash.meta` |

## 自定义配置 overlay.yaml

订阅每次都会重写 `config.yaml`。把长期有效的 DNS、TUN、额外规则放到数据卷中的 `overlay.yaml`（示例见 [`examples/overlay.yaml`](examples/overlay.yaml)）：

```yaml
dns:
  enable: true
  enhanced-mode: fake-ip
rules-prepend:
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
```

`mixed-port` / `secret` / `external-controller` 仍由环境变量管理，不会被 overlay 覆盖。

## 家庭订阅出口

把 25500 映射到局域网后，其他设备可导入（将 token 换成日志里的订阅令牌）：

```
http://<主机IP>:25500/getprofile?name=profiles/clash.ini&token=<SUB_TOKEN>
http://<主机IP>:25500/getprofile?name=profiles/surge.ini&token=<SUB_TOKEN>
http://<主机IP>:25500/getprofile?name=profiles/quanx.ini&token=<SUB_TOKEN>
http://<主机IP>:25500/getprofile?name=profiles/singbox.ini&token=<SUB_TOKEN>
```

远程访问请走 Tailscale 或类似隧道，不要把 25500 放到公网。

## TUN 模式

仅建议在软路由 / 需要接管全局流量时使用。先准备 `overlay.yaml` 打开 `tun.enable`，再：

```bash
docker compose -f docker-compose.tun.yml up -d
```

该文件使用 `network_mode: host`、`NET_ADMIN` 和 `/dev/net/tun`。配置不当会断网，先在测试机验证。

## 数据目录

| 路径 | 说明 |
| --- | --- |
| `/root/.config/mihomo/config.yaml` | 当前运行配置 |
| `/root/.config/mihomo/config.yaml.good` | 上一份转换成功的配置 |
| `/root/.config/mihomo/overlay.yaml` | 用户覆盖层 |
| `/root/.config/mihomo/log.txt` | 订阅更新日志 |
| `/root/.config/mihomo/ui` | Zashboard |
| `/root/.config/mihomo/.secret` | 持久化 API 密钥 |

## 镜像标签

推送到 `main` 时按 [`VERSION`](VERSION) 打标签。

| 标签 | 说明 |
| --- | --- |
| `latest` | `main` 最新稳定构建 |
| `*.*.*` | `VERSION` 中的语义化版本 |
| `YYYYMMDD-sha` | 单次构建回溯 |
| `main` | `main` 分支最新代码 |

## 许可证

[MIT License](LICENSE)。本仓库图标为原创几何图形，未使用 Docker / MetaCubeX 官方商标文件。
