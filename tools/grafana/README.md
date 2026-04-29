# Grafana

Unified dashboards for CyberBlueSOC. Connects to the indexers already running in the core stack so you get one pane of glass across Wazuh alerts, Shuffle workflows, TheHive cases, and Zeek metadata.

## URL & default credentials

| Item | Value |
|---|---|
| URL | `http://<host>:3000` |
| User | `admin` |
| Password | `cyberblue` (override with `GRAFANA_ADMIN_PASSWORD` in `.env`) |

## What's pre-provisioned

- **Datasources**: Wazuh Indexer, Shuffle OpenSearch, TheHive Elasticsearch, Prometheus placeholder.
- **Plugins**: `grafana-opensearch-datasource`, `grafana-piechart-panel`, `grafana-worldmap-panel`.
- **Dashboard**: `CyberBlueSOC — Overview` (starter dashboard with Wazuh alert counts; expand from there).

## Bring up

```bash
# from repo root
docker compose -f docker-compose.extras.yml --profile standard up -d grafana
```

## Adding more dashboards

Drop any Grafana dashboard JSON into `tools/grafana/dashboards/`. Grafana auto-loads them every 30 s into the `CyberBlueSOC` folder.

Suggested community dashboards:

| Source | What it covers |
|---|---|
| Grafana ID 11176 | Wazuh — SOC dashboard |
| Grafana ID 12860 | Suricata alerts |
| Grafana ID 7587 | Docker host overview |

Import via UI or save the exported JSON into `tools/grafana/dashboards/`.

## Resource footprint

| Resource | Idle |
|---|---|
| RAM | ~150-250 MB |
| CPU | low |
| Disk | minimal |
