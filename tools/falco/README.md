# Falco

> **Profile**: `[falco]` (NOT `standard`). Opt-in with `--profile falco` because
> Falco's prebuilt drivers may lag your kernel by a few weeks; on very new
> cloud kernels it can fail to load. Test before promoting back to `standard`.
>
> **Bring up**:
> `docker compose -f docker-compose.yml -f docker-compose.extras.yml --profile falco up -d`

[Falco](https://falco.org/) is the open-source runtime security project from the CNCF. It watches the Linux kernel via eBPF and alerts on suspicious behavior **inside running containers** — shells in containers, writes to sensitive paths, suspicious child processes, crypto-mining patterns, etc.

This is the missing layer on a containerized SOC stack: everything else watches the network or the data; Falco watches the platform itself.

## What gets installed

| Component | Role |
|---|---|
| `falco` | The detection engine. Runs with `modern-bpf` (no kernel module compile needed). |
| `falcosidekick` | Ships Falco events to webhooks (Shuffle, Slack, etc.). API on `:2801`. |
| `falcosidekick-ui` | Web UI to browse events. URL: `http://<host>:2802` |
| `falcosidekick-ui-redis` | Backing store for the UI. |

## Default rules cover

- Shell spawned in a container
- Writes below `/etc`, `/var/log`, `/usr/bin`
- Crypto-miner indicators
- Suspicious network activity from inside containers
- File integrity violations
- Container drift (binary not in original image)
- Privileged container creation

Custom rules go into `tools/falco/config/` (mounted at `/etc/falco/`).

## URLs

| Item | URL |
|---|---|
| Falcosidekick UI | `http://<host>:2802` |
| Falcosidekick API | `http://<host>:2801` |

## Bring up

```bash
docker compose -f docker-compose.extras.yml --profile standard up -d falco falcosidekick falcosidekick-ui falcosidekick-ui-redis
docker logs -f falco | grep -E 'Notice|Warning|Critical'
```

## Trigger a test event

```bash
docker exec -it suricata sh -c 'cat /etc/shadow' || true
# Falco should fire: "Read sensitive file untrusted"
```

Watch:

```bash
docker logs -f falco
# or open the UI: http://<host>:2802
```

## Wire to Shuffle (optional)

In `docker-compose.yml`, uncomment and set:

```yaml
WEBHOOK_ADDRESS: "http://shuffle-frontend:3001/api/v1/hooks/<your-webhook-id>"
```

Then every Falco alert becomes a Shuffle workflow trigger.

## Important notes

- Requires `privileged: true` and `pid: host`. This is **required** to read kernel events. Lab use only.
- Uses `--modern-bpf` which works on Linux 5.8+ without compiling drivers. Confirmed working on Ubuntu 24.04 and standard AWS Nitro instances.
- If `--modern-bpf` fails (older kernel), switch to the classic image `falcosecurity/falco:latest` which uses the kernel module.

## Resource footprint

| Resource | Idle | Active |
|---|---|---|
| RAM | ~250 MB total | up to 500 MB |
| CPU | low | scales with syscall volume |
