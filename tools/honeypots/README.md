# Honeypots

Two honeypots, complementary by design:

| Honeypot | What it pretends to be | Use case |
|---|---|---|
| **Cowrie** | Realistic SSH + Telnet shell. Logs every command, captures uploaded files. | Catch automated SSH brute-force, study attacker tradecraft. |
| **OpenCanary** | Lightweight, multi-protocol (FTP, HTTP, IMAP, MSSQL, VNC). Pure detection, no shell. | Cheap tripwires across many services. Pair with Wazuh/Shuffle for alerting. |

## Exposed ports

> Honeypots are intentionally exposed. The whole point is for attackers to find them. **Only run on isolated lab networks.**

| Service | Port | Honeypot |
|---|---|---|
| SSH | 2222 | Cowrie |
| Telnet | 2223 | Cowrie |
| FTP | 2121 | OpenCanary |
| HTTP | 2380 | OpenCanary |
| IMAP | 2143 | OpenCanary |
| MSSQL | 1433 | OpenCanary |
| VNC | 5900 | OpenCanary |

If a port collides with something already in use on the host, edit `docker-compose.yml` here.

## Logs

| Honeypot | Path on host |
|---|---|
| Cowrie | `tools/honeypots/cowrie/var/log/cowrie/` |
| OpenCanary | `tools/honeypots/opencanary/var/opencanary.log` |

These directories are mounted volumes so logs survive container restarts and can be ingested by Wazuh's filebeat.

## Bring up

```bash
# from repo root
docker compose -f docker-compose.extras.yml --profile standard up -d cowrie opencanary
```

## Verify (from another host)

```bash
ssh -p 2222 root@<host>          # Cowrie should accept any password
nc <host> 1433                   # Triggers OpenCanary MSSQL alert
curl http://<host>:2380          # Triggers OpenCanary HTTP alert
```

Watch:

```bash
docker logs -f cowrie
docker logs -f opencanary
```

## Wire into Shuffle (optional)

OpenCanary can post webhook alerts. Add to `opencanary/etc/opencanary.conf`:

```json
"logger.kwargs.handlers.webhook": {
  "class": "opencanary.logger.SlackHandler",
  "webhook_url": "http://shuffle-frontend:3001/api/v1/hooks/webhook_<id>"
}
```

## Resource footprint

| Resource | Idle (both) | Active |
|---|---|---|
| RAM | ~150 MB | ~250 MB |
| CPU | very low | spikes during scans |
| Disk | minimal until logs accumulate | rotation built into Cowrie + OpenCanary |
