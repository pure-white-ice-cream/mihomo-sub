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

内置 **Mihomo v1.19.31**、**Zashboard v3.26.0**、Subconverter v0.9.2。

## 3.0.0 破坏性变更

从 2.x 升级请先看这些环境变量变化，再拉 `3.0.0` / `latest`：

- 未设置 `SECRET` 时会**生成随机密钥**，面板不再默认无密码。局域网不要密码请显式 `SECRET: off`
- 未设置 `cron` 时默认 **每天 4:00** 更新，不再省略定时任务。不定期更新（只在启动时拉一次）请 `cron: off`
- 推荐改用命名卷 `data`，不要再绑 `./data`

## 适合谁 / 不适合谁

**适合：** 有自己的订阅链接，想在 NAS、软路由或家用 Linux 上一容器跑起来；局域网设备走 mixed 端口；手机再导入同一套转换结果。

**不适合：** 当公开订阅站或公开转换 SaaS；把 7890/9090/25500 直接映射到公网；用本镜像分发他人节点。

## 特性

- Mihomo 内核 + Subconverter + Zashboard
- 定时更新订阅，失败保留上一份可用配置
- 多订阅合并（`sub_url` 用 `|` 分隔）
- `overlay.yaml` 和 `overlay.js` 保留自定义 DNS / 规则 / TUN
- 面板 API 密钥（未设置则首次启动生成；`SECRET=off` 可关）
- 可选家庭订阅出口（clash / surge / quanx / sing-box）
- `linux/amd64` `linux/arm64` `linux/arm/v7` `linux/386`

## 快速开始

仓库根目录已有 [`docker-compose.yml`](docker-compose.yml)。也可以直接复制下面的示例。

### Docker Compose

```yaml
services:
  mihomo:
    image: purewhiteicecream/mihomo-sub:latest
    container_name: mihomo-sub
    environment:
      TZ: Asia/Shanghai
      sub_url: https://your-subscription-url.com
      # 不定期更新（仅启动时拉取一次）改为 off
      cron: "0 4 * * *"
      # 局域网面板不要密码时改为 off，不要把 9090 暴露到公网
      SECRET: change-me
    volumes:
      - data:/root/.config/mihomo
    ports:
      - "7890:7890"   # mixed 代理
      - "9090:9090"   # Web 面板
    restart: unless-stopped

volumes:
  data:
```

```bash
docker compose up -d
```

打开 `http://<主机IP>:9090/ui`，在面板设置里填入 `SECRET`。

### Docker Run

```bash
docker run -d \
  --name mihomo-sub \
  -e TZ=Asia/Shanghai \
  -e sub_url="https://your-subscription-url.com" \
  -e cron="0 4 * * *" \
  -e SECRET=change-me \
  -p 7890:7890 \
  -p 9090:9090 \
  -v mihomo-data:/root/.config/mihomo \
  purewhiteicecream/mihomo-sub:latest
```

国内若拉 Docker Hub 不稳定，把镜像名换成 `ghcr.io/pure-white-ice-cream/mihomo-sub:latest`。1Panel / CasaOS / Portainer 也可导入 [`deploy/portainer-stack.yml`](deploy/portainer-stack.yml)。

## 启动后

1. 带密钥部署：看容器日志里的 **API 密钥**（未指定 `SECRET` 时首次启动会生成并写入数据卷），打开 `http://<主机IP>:9090/ui` 填入同一密钥。
2. `SECRET=off`：直接打开面板即可，不用填密钥。
3. 系统 / 浏览器代理填 `HTTP/SOCKS`：`<主机IP>:7890`。
4. 不要把 7890、9090、25500 直接暴露到公网。

常见失败：

| 现象 | 处理 |
| --- | --- |
| 订阅 403 / 空内容 | 检查链接、更新间隔；默认每天 4:00，过频容易被封 |
| 面板打不开 / 一直要密钥 | 确认映射了 9090；有密钥时填日志中的 `SECRET`；不想要密钥则设 `SECRET=off` |
| 局域网连不上代理 | `ALLOW_LAN=true`（默认已是） |
| 更新后自定义规则消失 | 把规则放到命名卷里的 `overlay.yaml` |

## 环境变量

| 变量 | 说明 | 默认 |
| --- | --- | --- |
| `TZ` | 时区 | `Asia/Shanghai` |
| `sub_url` | 订阅链接，多条用 `\|` 分隔，**必填** | 无 |
| `config_url` | Subconverter 外部规则模板 | 无 |
| `cron` | 更新计划；`off` 关闭定时 | `0 4 * * *` |
| `SECRET` | 面板 / Clash API 密钥；留空则生成；`off` 关闭密钥 | 随机 |
| `ALLOW_LAN` | 是否允许局域网访问代理端口 | `true` |
| `MIXED_PORT` | mixed 端口 | `7890` |
| `CONTROLLER_PORT` | 面板端口 | `9090` |
| `NOTIFY_WEBHOOK` | 失败时 POST `{"status","message"}` | 无 |
| `SUB_TOKEN` | 家庭订阅令牌，留空则生成 | 随机 |
| `SUB_UA` | 拉取订阅时的 User-Agent | `clash.meta` |

## 进阶教程

### 自定义配置 overlay.yaml

订阅每次都会重写 `config.yaml`。把需要保留的 DNS、TUN 和额外规则写进数据卷里的 `overlay.yaml`。也可以把本地的 `.yml` 文件挂载到容器内的 `/root/.config/mihomo/overlay.yaml`。更多写法见 [`examples/overlay.yaml`](examples/overlay.yaml)。

```yaml
dns:
  enable: true
  enhanced-mode: fake-ip
rules-prepend:
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
```

同名映射按键合并，同名列表整段覆盖。用 `rules-prepend` 把新规则加到规则表前面，用 `rules-append` 加到末尾。订阅里有 `MATCH` 兜底规则时，用 `rules-prepend` 让新规则先匹配。

### JavaScript 覆写 overlay.js

从 3.1.0 起，可以用 `overlay.js` 按节点名筛选节点、调整策略组或修改规则。订阅转换后先合并 `overlay.yaml`，再把结果作为对象传给同步函数 `main(config)`。函数需要返回完整的配置对象。

在 Compose 文件旁创建 `overlay.js`。下面的脚本会把一条直连规则放到规则表开头。

```js
function main(config) {
  config.rules = ["DOMAIN-SUFFIX,example.com,DIRECT", ...(config.rules || [])]
  return config
}
```

保留原来的数据卷，在 `mihomo` 服务的 `volumes` 里加上脚本的只读挂载。

```yaml
    volumes:
      - data:/root/.config/mihomo
      - ./overlay.js:/root/.config/mihomo/overlay.js:ro
```

执行 `docker compose up -d` 应用挂载。脚本在每次订阅更新时运行，也可以用 `docker compose exec mihomo /usr/local/bin/sub.sh` 手动更新。

只挂载你信任的本地脚本。执行环境提供 JavaScript 内置对象，订阅配置通过 `config` 传入，执行上限为 5 秒。面板密钥会从传入的对象中移除，容器在覆写后写回密钥、端口等受管字段。

候选配置通过 Mihomo 校验后才会替换 `config.yaml`。脚本报错、超时、返回值无效或配置校验失败时，保留当前配置和 `config.yaml.good`，并记录到 `log.txt`。覆写只用于容器内运行的 Mihomo 配置。家庭订阅出口由 Subconverter 生成。

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
| `/root/.config/mihomo/overlay.yaml` | YAML 覆写 |
| `/root/.config/mihomo/overlay.js` | JavaScript 覆写脚本 |
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
