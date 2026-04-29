# Zeek

[Zeek](https://zeek.org/) is the network security monitor that gives you protocol-level metadata (DNS, HTTP, TLS, SSH, SMB, files, certificates, ...) for every connection on the wire. It's the second pillar of network monitoring alongside Suricata, which already lives in the core CyberBlueSOC stack.

## What it adds to CyberBlueSOC

- Per-connection logs (`conn.log`)
- DNS, HTTP, SSL, SSH, SMB, FTP, Kerberos protocol logs
- File extraction with MD5/SHA1/SHA256 hashes
- Notices for SQLi, weak certs, scanning activity
- All output as **JSON**, ready for OpenSearch / Wazuh-indexer / Grafana

## Where logs land

Logs are written to `tools/zeek/logs/current/` on the host. Filebeat (already shipped via Wazuh) can be pointed at this directory to forward into Wazuh-indexer.

## Configuration

- `config/local.zeek` — site policy. Edit to enable additional analyzers or change subnets.
- Default monitored interface is `eth0`. Override via `.env`:

  ```bash
  ZEEK_INTERFACE=ens5
  ```

## Bring up

```bash
# from repo root
docker compose -f docker-compose.extras.yml --profile standard up -d zeek
docker logs -f zeek
```

## Verify

```bash
ls tools/zeek/logs/current/
# expect: conn.log, dns.log, http.log, ssl.log, files.log, ...

tail -1 tools/zeek/logs/current/conn.log | jq .
```

## Resource footprint

| Resource | Idle | Active |
|---|---|---|
| RAM | ~150 MB | ~300-500 MB |
| CPU | low | scales with traffic |
| Disk | grows with logs (rotation handled by Zeek) |

## Security note

Runs in `network_mode: host` and requires `NET_ADMIN` + `NET_RAW` to sniff. This is intentional and required for any packet-level tool. Keep it in a lab environment only.
