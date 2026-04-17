# CrowdSec

[CrowdSec](https://www.crowdsec.net/) is a modern, behavioral, **community-powered** intrusion prevention engine. Think of it as a smarter `fail2ban` that also learns from a global threat-sharing network.

## Why we ship it

- Reads existing logs (sshd, nginx, iptables, Cowrie) and detects scenarios (brute-force, scanning, web-CVE exploitation, etc.).
- Plugs into the **CrowdSec community blocklist** — millions of IPs reported by other users.
- Exposes a Local API (LAPI) that "bouncers" can query to actually block traffic at firewall, nginx, or cloud level.
- Exports Prometheus metrics for Grafana.

## URLs

| Item | URL |
|---|---|
| LAPI | `http://<host>:8090` |
| Metrics (Prometheus) | `http://<host>:6060/metrics` |

## Pre-installed collections

Configured via `COLLECTIONS` env var:

- `crowdsecurity/sshd`
- `crowdsecurity/linux`
- `crowdsecurity/iptables`
- `crowdsecurity/http-cve`
- `crowdsecurity/nginx`
- `crowdsecurity/wordpress`

Add more inside the running container:

```bash
docker exec -it crowdsec cscli collections install crowdsecurity/<name>
```

## Bring up

```bash
docker compose -f docker-compose.extras.yml --profile standard up -d crowdsec
```

## Verify

```bash
docker exec -it crowdsec cscli metrics
docker exec -it crowdsec cscli decisions list
docker exec -it crowdsec cscli alerts list
```

## Wire to a bouncer (block traffic for real)

A "bouncer" is the enforcement side. Common ones:

| Bouncer | Where it blocks |
|---|---|
| `cs-firewall-bouncer` | iptables / nftables on the host |
| `cs-nginx-bouncer` | inside Nginx |
| `cs-cloudflare-bouncer` | at Cloudflare's edge |

Install on host (example for firewall):

```bash
sudo apt install crowdsec-firewall-bouncer-iptables
sudo cscli bouncers add firewallBouncer
# paste the API key into /etc/crowdsec/bouncers/cs-firewall-bouncer.yaml
sudo systemctl restart crowdsec-firewall-bouncer
```

## Resource footprint

| Resource | Idle |
|---|---|
| RAM | ~100-150 MB |
| CPU | low (event-driven) |
| Disk | small DB |
