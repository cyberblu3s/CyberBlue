# CyberBlueSOC Tools (Extras)

This folder holds **additional SOC capabilities** layered on top of the core CyberBlueSOC stack.

The goal is to evolve CyberBlueSOC into a **complete SOC platform** by closing the gaps in the core stack:

| Gap | Filled by |
|---|---|
| Network metadata (Zeek-style logs) | `zeek/` |
| Cross-tool dashboards | `grafana/` |
| Honeypots / deception | `honeypots/` (Cowrie + OpenCanary) |
| Behavioral IPS + community blocklist | `crowdsec/` |
| Container runtime security | `falco/` |
| Vulnerability scanning, forensics, malware triage (CLI) | `native/` |

## Why a separate folder

- The **core** `docker-compose.yml` (Wazuh, Suricata, MISP, TheHive, Shuffle, Velociraptor, Caldera, etc.) stays untouched.
- The **extras** are opt-in via Compose profiles, so users on smaller hardware can skip them.
- This is the model SecurityOnion uses (Eval / Standalone / Distributed) and the model the future ISO will use to ship multiple profiles from one source.

## Profiles

Each tool's compose file declares one or more of these profiles:

| Profile | Audience | Approx RAM impact |
|---|---|---|
| `standard` | Default — Zeek, Grafana, Cowrie, OpenCanary, CrowdSec | ~1.0 GB |
| `falco` | Container runtime security (opt-in; may need newer driver for very recent kernels) | ~300 MB |
| `full` | Heavy additions for users with 32+ GB (OpenCTI, GVM, etc.) | ~6-8 GB |

To bring up the standard extras alongside the core stack:

```bash
# from repo root
docker compose -f docker-compose.yml -f docker-compose.extras.yml --profile standard up -d
```

To stop them:

```bash
docker compose -f docker-compose.extras.yml --profile standard down
```

## Folder layout

```
tools/
├── README.md                  ← this file
├── zeek/                      ← network metadata
│   ├── docker-compose.yml
│   ├── README.md
│   ├── config/
│   └── logs/                  ← gitignored, runtime
├── grafana/                   ← unified dashboards
│   ├── docker-compose.yml
│   ├── README.md
│   ├── provisioning/
│   └── dashboards/
├── honeypots/                 ← Cowrie + OpenCanary
│   ├── docker-compose.yml
│   ├── README.md
│   └── cowrie/, opencanary/
├── crowdsec/                  ← behavioral IPS
│   ├── docker-compose.yml
│   ├── README.md
│   └── config/
├── falco/                     ← container runtime security
│   ├── docker-compose.yml
│   ├── README.md
│   └── config/
└── native/                    ← host-installed CLI tools
    ├── install.sh             ← installs nuclei, trivy, volatility3, plaso, sigma-cli
    └── README.md
```

## Native vs Docker

Not every SOC tool belongs in a container. Following the Kali model:

- **Always-on services** → Docker (Zeek, Grafana, honeypots, CrowdSec, Falco)
- **CLI / on-demand tools** → Native install via `tools/native/install.sh` (Nuclei, Trivy, Volatility 3, plaso, sigma-cli)
- **Desktop GUI apps** → Native (Wireshark, CyberChef Desktop, Autopsy)

This keeps idle RAM low and matches user expectation that `nuclei` and `volatility` are commands, not URLs.

## Adding a new tool

1. Create `tools/<your-tool>/` with its own `docker-compose.yml` and `README.md`.
2. Tag every service with `profiles: [standard]` or `[full]` as appropriate.
3. Add its compose file to the top-level `docker-compose.extras.yml` `include:` block.
4. Document the URL, default credentials, and any host requirements in the tool's README.
5. Open a PR.

The pattern is intentionally copy-pasteable.
