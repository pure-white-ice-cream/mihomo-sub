<p align="center">
  <img src="assets/logo.svg" width="96" height="96" alt="mihomo-sub Folded Hatch logo">
</p>

<h1 align="center">mihomo-sub</h1>

<p align="center">
  <a href="README.md">简体中文</a> · <strong>English</strong>
</p>

<p align="center">
  <strong>Run an existing proxy subscription on your NAS or home router.</strong><br>
  The container bundles Mihomo, Zashboard, and Subconverter. It can refresh subscriptions on a schedule and serve converted profiles to other devices on your LAN.
</p>

<p align="center">
  <a href="https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml"><img src="https://github.com/pure-white-ice-cream/mihomo-sub/actions/workflows/docker-publish.yml/badge.svg" alt="Docker Build and Publish"></a>
  <a href="VERSION"><img src="https://img.shields.io/docker/v/purewhiteicecream/mihomo-sub?sort=semver&amp;label=version" alt="Image Version"></a>
  <a href="https://hub.docker.com/r/purewhiteicecream/mihomo-sub"><img src="https://img.shields.io/docker/pulls/purewhiteicecream/mihomo-sub" alt="Docker Hub Pulls"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/pure-white-ice-cream/mihomo-sub" alt="License"></a>
  <a href="https://linux.do"><img src="https://img.shields.io/badge/LINUX-DO-FFB003.svg?logo=data:image/svg%2bxml;base64,DQo8c3ZnIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjEwMCIgaGVpZ2h0PSIxMDAiPjxwYXRoIGQ9Ik00Ni44Mi0uMDU1aDYuMjVxMjMuOTY5IDIuMDYyIDM4IDIxLjQyNmM1LjI1OCA3LjY3NiA4LjIxNSAxNi4xNTYgOC44NzUgMjUuNDV2Ni4yNXEtMi4wNjQgMjMuOTY4LTIxLjQzIDM4LTExLjUxMiA3Ljg4NS0yNS40NDUgOC44NzRoLTYuMjVxLTIzLjk3LTIuMDY0LTM4LjAwNC0yMS40M1EuOTcxIDY3LjA1Ni0uMDU0IDUzLjE4di02LjQ3M0MxLjM2MiAzMC43ODEgOC41MDMgMTguMTQ4IDIxLjM3IDguODE3IDI5LjA0NyAzLjU2MiAzNy41MjcuNjA0IDQ2LjgyMS0uMDU2IiBzdHlsZT0ic3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOmV2ZW5vZGQ7ZmlsbDojZWNlY2VjO2ZpbGwtb3BhY2l0eToxIi8+PHBhdGggZD0iTTQ3LjI2NiAyLjk1N3EyMi41My0uNjUgMzcuNzc3IDE1LjczOGE0OS43IDQ5LjcgMCAwIDEgNi44NjcgMTAuMTU3cS00MS45NjQuMjIyLTgzLjkzIDAgOS43NS0xOC42MTYgMzAuMDI0LTI0LjM4N2E2MSA2MSAwIDAgMSA5LjI2Mi0xLjUwOCIgc3R5bGU9InN0cm9rZTpub25lO2ZpbGwtcnVsZTpldmVub2RkO2ZpbGw6IzE5MTkxOTtmaWxsLW9wYWNpdHk6MSIvPjxwYXRoIGQ9Ik03Ljk4IDcwLjkyNmMyNy45NzctLjAzNSA1NS45NTQgMCA4My45My4xMTNRODMuNDI2IDg3LjQ3MyA2Ni4xMyA5NC4wODZxLTE4LjgxIDYuNTQ0LTM2LjgzMi0xLjg5OC0xNC4yMDMtNy4wOS0yMS4zMTctMjEuMjYyIiBzdHlsZT0ic3Ryb2tlOm5vbmU7ZmlsbC1ydWxlOmV2ZW5vZGQ7ZmlsbDojZjlhZjAwO2ZpbGwtb3BhY2l0eToxIi8+PC9zdmc+" alt="Linux DO"></a>
</p>

Includes Mihomo **v1.19.33**, Zashboard **v3.30.0** with system fonts, and Subconverter **v0.9.2**. Images are available for `linux/amd64`, `linux/arm64`, `linux/arm/v7`, and `linux/386`.

## Quick start

### Docker Compose

1. Put [docker-compose.yml](docker-compose.yml) and [.env.example](.env.example) in the same directory.
2. Copy `.env.example` to `.env` and set `sub_url` to your subscription URL. Use `|` between URLs if you have more than one.
3. Run `docker compose up -d` in that directory.
4. Open `http://<host-ip>:9090/ui/` and enter `SECRET`. If you left it blank, the container generates a secret. Find it with `docker compose logs mihomo`.

Set your client's HTTP or SOCKS proxy to `<host-ip>:7890`. The dashboard starts first and the initial subscription refresh runs in the background. Check the container logs to see when the nodes are ready.

The Docker Hub image is `purewhiteicecream/mihomo-sub`. You can also use `ghcr.io/pure-white-ice-cream/mihomo-sub:latest` in Compose. For 1Panel, CasaOS, or Portainer, use the [stack example](deploy/portainer-stack.yml).

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

Use `docker logs mihomo-sub` to find the generated dashboard secret. Restrict the proxy and controller ports to your LAN.

## Settings

Most setups only need `sub_url`. The Compose file passes these settings from `.env` to the container.

| Variable | Use |
| --- | --- |
| `sub_url` | Subscription URL. Separate multiple URLs with `\|` |
| `SECRET` | Dashboard secret. Leave blank to generate and save one. Set `off` on a trusted LAN if you want open access |
| `cron` | Refreshes daily at 04:00 by default. Set `off` for one refresh at each startup |
| `TZ` | Time zone, defaults to `Asia/Shanghai` |
| `ALLOW_LAN` | Allows LAN clients to use the proxy port, defaults to `true` |
| `MIXED_PORT` / `CONTROLLER_PORT` | Proxy and dashboard ports inside the container, default to `7890` / `9090`. Check the Compose port mappings if you change them |
| `config_url` | Optional external Subconverter rule template |
| `SUB_UA` | User-Agent for subscription downloads, defaults to `clash.meta` |
| `SUB_TOKEN` | LAN subscription access token. Leave blank to generate and save one |
| `NOTIFY_WEBHOOK` | Sends a POST with `{"status","message"}` when an update fails |

Run `docker compose exec mihomo /usr/local/bin/sub.sh` to refresh now. A failed refresh keeps the current config. Look for the reason in the container logs or `log.txt` in the data volume.

## Advanced usage

### Start offline

On a machine with internet access, download the `.tar.gz` for your device from [GitHub Releases](https://github.com/pure-white-ice-cream/mihomo-sub/releases). The filename includes `linux-amd64`, `linux-arm64`, `linux-arm-v7`, or `linux-386`. On Linux, you can put `SHA256SUMS` from the same release next to the archive and run `sha256sum -c --ignore-missing SHA256SUMS` to verify the download.

Copy the archive, `docker-compose.yml`, and your prepared `.env` to the target machine. This example loads the 3.1.2 archive for amd64. Use the filename you downloaded.

```bash
docker load -i mihomo-sub-3.1.2-linux-amd64.tar.gz
```

Docker restores the version tag from the archive. Set the Compose `image` to that tag, for example `purewhiteicecream/mihomo-sub:3.1.2`. Then start from the local image.

```bash
docker compose up -d --pull never
```

You can reuse the same archive on several devices. The target machine can stay disconnected from the internet while you load the image, start the container, and open the bundled `/ui/` from the LAN. A fresh volume uses your configured ports and `SECRET`. Nodes appear after the first successful refresh. An existing volume starts with its saved configuration.

### overlay.yaml

Subscription refreshes regenerate `config.yaml`. Put custom DNS, TUN, and rules in `overlay.yaml` in the data volume. You can also mount a local `.yml` file at `/root/.config/mihomo/overlay.yaml`. [YAML example](examples/overlay.yaml)

Maps merge by key. Lists replace the corresponding list. Use `rules-prepend` to insert rules at the front or `rules-append` to put them at the end. A rule that must take precedence over `MATCH` belongs at the front.

### overlay.js

Use a script to filter nodes by name or adjust groups. The container applies `overlay.yaml` first, then calls your synchronous `main(config)`. Return the full config object.

This example puts a direct rule first.

```js
function main(config) {
  config.rules = ["DOMAIN-SUFFIX,example.com,DIRECT", ...(config.rules || [])]
  return config
}
```

Save the script beside the Compose file, add the following line to the `mihomo` service's `volumes`, and run `docker compose up -d`.

```yaml
      - ./overlay.js:/root/.config/mihomo/overlay.js:ro
```

Use a local script you trust. It runs in a separate environment and has five seconds to finish. The container removes the dashboard secret from the script input. It restores the ports and secret before Mihomo validates the result. Script errors, timeouts, and failed validation keep the current config and its backup.

The overlays apply to Mihomo inside the container. Subconverter generates LAN profiles separately.

### TUN

To route traffic through a home router, enable `tun.enable` in `overlay.yaml` and start with the TUN Compose file.

```bash
docker compose -f docker-compose.tun.yml up -d
```

This uses host networking, `NET_ADMIN`, and `/dev/net/tun`. [TUN Compose](docker-compose.tun.yml)

## Share profiles on the LAN

Publish port `25500` on the LAN. Replace the host address and token below to import the converted Clash profile.

```text
http://<host-ip>:25500/getprofile?name=profiles/clash.ini&token=<SUB_TOKEN>
```

For other formats, use `surge.ini`, `quanx.ini`, or `singbox.ini`. The startup logs show the generated token.

## Data and versions

Keep the volume mounted at `/root/.config/mihomo` when you recreate the container. It holds the current `config.yaml`, the `config.yaml.good` backup, and the saved secret and token in `.secret` and `.sub_token`. The image supplies the dashboard files.

Use `latest` to follow releases or pin an image version. Back up the data volume before an upgrade. The repository version is in [VERSION](VERSION). Build and release checks are in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT License](LICENSE)
