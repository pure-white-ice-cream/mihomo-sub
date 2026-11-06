<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="mihomo-sub 折舱标志">
</p>

# mihomo-sub

把已有的代理订阅放到 NAS 或软路由上跑。容器内置 Mihomo、Zashboard 和 Subconverter，能定时更新订阅，也能把转换后的订阅提供给局域网里的其他设备。

[English](README.en.md)

[![Docker Build and Publish](https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml)
[![Version](https://img.shields.io/docker/v/purewhiteicecream/mihomo-sub?sort=semver&label=version)](VERSION)
[![Docker Pulls](https://img.shields.io/docker/pulls/purewhiteicecream/mihomo-sub)](https://hub.docker.com/r/purewhiteicecream/mihomo-sub)
[![License](https://img.shields.io/github/license/pure-white-ice-cream/mihomo-sub)](LICENSE)

内置 Mihomo **v1.19.33**、Zashboard **v3.30.0**（系统字体包）和 Subconverter **v0.9.2**。镜像支持 `linux/amd64`、`linux/arm64`、`linux/arm/v7` 和 `linux/386`。

## 快速开始

### Docker Compose

1. 下载仓库里的 [docker-compose.yml](docker-compose.yml) 和 [.env.example](.env.example)，放在同一个目录。
2. 把 `.env.example` 复制为 `.env`，把 `sub_url` 改成你的订阅地址。有多条订阅时用 `|` 分隔。
3. 在该目录运行 `docker compose up -d`。
4. 浏览器打开 `http://<主机IP>:9090/ui/`。首次访问时填入 `SECRET`。如果没有设置它，容器会生成一个密钥，可用 `docker compose logs mihomo` 查看。

客户端的 HTTP 或 SOCKS 代理地址填 `<主机IP>:7890`。容器先启动面板，再在后台拉取订阅。首次配置时，可以在日志里看下载和转换是否已经完成。

Docker Hub 镜像是 `purewhiteicecream/mihomo-sub`。也可以将 Compose 里的 `image` 改成 `ghcr.io/pure-white-ice-cream/mihomo-sub:latest`。1Panel、CasaOS 或 Portainer 可以导入 [Portainer Stack 示例](deploy/portainer-stack.yml)。

### Docker Run

```bash
docker run -d --name mihomo-sub \
  --restart unless-stopped \
  -e sub_url='https://example.com/subscription' \
  -p 7890:7890 \
  -p 9090:9090 \
  -v mihomo-data:/root/.config/mihomo \
  purewhiteicecream/mihomo-sub:latest
```

用 `docker logs mihomo-sub` 查看生成的面板密钥。把代理端口和控制端口限制在局域网内。

## 常用设置

大部分部署只需填写 `sub_url`。下面这些值可以在 `.env` 里调整。项目的 Compose 文件会把它们传给容器。

| 变量 | 用法 |
| --- | --- |
| `sub_url` | 订阅地址。多条用 `\|` 分隔 |
| `SECRET` | 面板密钥。留空会生成并保存。填 `off` 可关闭鉴权，适合受控局域网 |
| `cron` | 默认每天 04:00 更新。填 `off` 时只在每次启动后更新一次 |
| `TZ` | 时区，默认 `Asia/Shanghai` |
| `ALLOW_LAN` | 是否允许局域网设备连接代理，默认 `true` |
| `MIXED_PORT` / `CONTROLLER_PORT` | 容器内的代理和面板端口，默认 `7890` / `9090`。改动时也要检查 Compose 的 `ports` |
| `config_url` | 可选的 Subconverter 外部规则模板 |
| `SUB_UA` | 拉取订阅用的 User-Agent，默认 `clash.meta` |
| `SUB_TOKEN` | 家庭订阅的访问令牌，留空会生成并保存 |
| `NOTIFY_WEBHOOK` | 更新失败时 POST `{"status","message"}` 到这个地址 |

要马上更新订阅，可以运行 `docker compose exec mihomo /usr/local/bin/sub.sh`。更新失败时，容器会保留当前配置。具体原因在容器日志和数据卷里的 `log.txt`。

## 进阶教程

### 离线启动

在能联网的机器上，从 [GitHub Releases](https://github.com/pure-white-ice-cream/mihomo-sub/releases) 下载与设备架构对应的 `.tar.gz`。文件名会标出 `linux-amd64`、`linux-arm64`、`linux-arm-v7` 或 `linux-386`。在 Linux 上，可以把同版本的 `SHA256SUMS` 放在镜像包旁边，运行 `sha256sum -c --ignore-missing SHA256SUMS` 校验下载的包。

把镜像包、`docker-compose.yml` 和准备好的 `.env` 拷到目标机器。以下用 3.1.2 的 amd64 包举例，导入时换成你下载的文件名。

```bash
docker load -i mihomo-sub-3.1.2-linux-amd64.tar.gz
```

导入会恢复镜像的版本标签。把 Compose 的 `image` 改为对应的标签，例如 `purewhiteicecream/mihomo-sub:3.1.2`，然后用本地镜像启动。

```bash
docker compose up -d --pull never
```

镜像包可以拷给多台设备。目标机器在没有外网的环境里也能导入、启动，再从局域网打开预装的 `/ui/`。空数据卷会按设定的端口和 `SECRET` 启动，节点在第一次订阅成功后出现。已有数据卷会先用保存的配置启动。

### 自定义配置 overlay.yaml

订阅更新会生成新的 `config.yaml`。想保留自定义 DNS、TUN 或分流规则，把它们写进数据卷的 `overlay.yaml`。也可以把本地的 `.yml` 文件挂载到 `/root/.config/mihomo/overlay.yaml`。 [YAML 示例](examples/overlay.yaml)

同名映射按键合并，同名列表整段替换。只想加几条规则时，用 `rules-prepend` 插入开头，或用 `rules-append` 加到末尾。订阅已有 `MATCH` 兜底时，把新规则放在前面才会先匹配。

<a name="overlay-js"></a>

### JavaScript 覆写 overlay.js

需要按节点名筛选或改策略组时，用 `overlay.js`。转换结果先合并 YAML 覆写，再传给同步的 `main(config)`。函数要返回完整的配置对象。

下面的脚本会在规则表开头加一条直连规则。

```js
function main(config) {
  config.rules = ["DOMAIN-SUFFIX,example.com,DIRECT", ...(config.rules || [])]
  return config
}
```

把脚本放在 Compose 文件旁，在 `mihomo` 服务已有的 `volumes` 下增加一行。

```yaml
      - ./overlay.js:/root/.config/mihomo/overlay.js:ro
```

保存后运行 `docker compose up -d`。只挂载你信任的本地脚本。脚本在独立环境里运行，上限是 5 秒，收到的配置已移除面板密钥。覆写结束后，容器写回端口和密钥，再用 Mihomo 校验候选配置。脚本报错、超时或校验失败时，当前配置和备份都会保留。

YAML 和 JS 覆写用于容器里运行的 Mihomo。家庭订阅出口由 Subconverter 单独生成。

### TUN 模式

软路由要接管网络流量时，可以在 `overlay.yaml` 中启用 `tun.enable`，再使用 TUN 版 Compose 文件。

```bash
docker compose -f docker-compose.tun.yml up -d
```

这个文件使用 host 网络、`NET_ADMIN` 和 `/dev/net/tun`。 [TUN Compose](docker-compose.tun.yml)

## 给家里其他设备用

把容器的 `25500` 端口映射到局域网。把下面的主机地址换成你的机器，再填入 `SUB_TOKEN`，即可导入转换后的订阅。

```text
http://<主机IP>:25500/getprofile?name=profiles/clash.ini&token=<SUB_TOKEN>
```

其他格式把 `clash.ini` 换成 `surge.ini`、`quanx.ini` 或 `singbox.ini`。生成的令牌也能在启动日志里找到。

## 数据和版本

重建容器时保留挂载到 `/root/.config/mihomo` 的数据卷。里面的 `config.yaml` 是当前配置，`config.yaml.good` 是备份，`.secret` 和 `.sub_token` 保存密钥和令牌。面板文件由镜像提供。

用 `latest` 跟随更新，也可以固定镜像版本。升级前先备份数据卷。仓库版本由 [VERSION](VERSION) 管理，构建与发布验收见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT License](LICENSE)
