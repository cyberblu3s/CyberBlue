# ARM64 Support

CyberBlueSOC is a dual-architecture platform. The same codebase, installers,
and documentation produce a working blue-team lab on both **amd64** (x86_64,
AWS / VMware / VirtualBox / bare metal) and **arm64** (AWS Graviton, Apple
Silicon via UTM, Raspberry Pi 4/5-class hardware).

This document is the operator-facing summary of what works, what doesn't,
and how to verify an arm64 install. For the engineering-level audits, see
[`tools/native/ARM64_AUDIT.md`](../tools/native/ARM64_AUDIT.md),
[`tools/native/desktop/ARM64_AUDIT.md`](../tools/native/desktop/ARM64_AUDIT.md),
and `ENHANCEMENTS.md` entries #50, #52, #53 in the workspace root.

## Supported host environments

| Environment | Architecture | Status | Notes |
|---|---|---|---|
| AWS EC2 (Intel / AMD) | amd64 | **reference** | Canonical build box; all phases validated here first |
| AWS EC2 Graviton (`t4g`, `c7g`, …) | arm64 | supported | Same install commands as amd64 |
| UTM on Apple Silicon (M1/M2/M3/M4/M5) | arm64 | **smoke-tested** | Phase 1 + Phase 4 passed on Ubuntu Server 24.04 LTS aarch64 |
| VMware Fusion / Parallels (Apple Silicon) | arm64 | supported, untested | Same Ubuntu Server 24.04 arm64 image |
| VMware / VirtualBox on x86 host | amd64 | supported | |
| Bare metal Intel / AMD | amd64 | supported | |
| Raspberry Pi 4/5 (8 GB+) | arm64 | supported, untested | 16 GB RAM strongly recommended for full stack |

## Dual-architecture matrix

### Docker container stack (`cyberblue_install.sh`)

| Component | amd64 | arm64 | Source / notes |
|---|---|---|---|
| Wazuh manager / indexer / dashboard | ✅ upstream | ✅ **local rebuild** | `wazuh/build-arm64-images.sh` builds from the vendored `build-docker-images/` sources; takes ~25 min on first install |
| Wazuh certs-generator | ✅ upstream | ✅ local rebuild | `wazuh/indexer-certs-creator/` built on demand |
| MISP (image + MISP-modules) | ✅ upstream | ✅ upstream multi-arch | |
| TheHive / Cortex | ✅ | ✅ | |
| Shuffle (frontend / backend / orborus / worker) | ✅ | ✅ | Core images are multi-arch |
| Shuffle `tenzir` integration | ✅ | ❌ | `frikky/shuffle:tenzir` is amd64-only; `tenzir-node` restarts on arm64 — **known limitation**, non-fatal |
| Velociraptor | ✅ | ✅ | |
| Caldera | ✅ | ✅ | Built locally; writable `conf/local.yml` bind required (was arch-agnostic bug) |
| Suricata | ✅ | ✅ | apt via OISF PPA; `SURICATA_INT` auto-detected |
| Zeek | ✅ | ✅ | |
| Arkime | ✅ | ✅ | `docker build --platform` aware |
| CyberChef | ✅ | ✅ | |
| EveBox | ✅ | ✅ | |
| Wireshark-web | ✅ | ✅ | |
| MITRE Navigator | ✅ | ✅ | |
| Portainer | ✅ | ✅ | |
| CyberBlue Portal | ✅ | ✅ | Built locally; Python base image is multi-arch |
| **Fleet (fleetdm + fleet-redis + fleet-mysql)** | ✅ | ❌ | **amd64-only**, runs under the `amd64` compose profile only. Not loaded on arm64 hosts. Use Velociraptor for arm64 endpoint management. |

### Native blue-team toolkit (`tools/native/install.sh`)

~56 CLI / GUI tools, all resolved and classified against the 4-bucket model
in `tools/native/ARM64_AUDIT.md`:

| Bucket | Count | Examples |
|---|---|---|
| green (native arm64) | 50 | nuclei, trivy, volatility3, yara, sigma-cli, wireshark, tshark, tcpdump, sleuthkit, binwalk, radare2, oletools, capa, floss, netexec, autopsy, plaso, chainsaw, hayabusa, zircolite, regripper, tenzir, jq, ripgrep, iocextract, hashid, … |
| fix-url (URL patched) | 3 | chainsaw, hayabusa, stratus (upstream ships arm64 but original URLs hardcoded amd64) |
| rebuild (deferred) | 1 | `bulk_extractor` — source build deferred; skipped on arm64 with a clear message |
| gap (amd64-only) | 2 | `sysmonforlinux` (Microsoft ships amd64 deb only), `zui` (Zui Labs ships amd64 deb only) — both skipped on arm64 with informative messages |

### Desktop UX layer (`tools/native/desktop/install-desktop.sh`)

| Component | arm64 status |
|---|---|
| XFCE desktop environment | ✅ apt, multi-arch |
| Branded wallpaper + logo | ✅ static PNG assets committed to repo |
| Welcome dashboard (HTML) | ✅ static HTML/CSS/JS |
| Application menu entries (76 categorized) | ✅ `.desktop` files, arch-agnostic |
| `cyberblue` CLI | ✅ shell script |
| Firefox (deb from Mozilla repo) | ✅ Mozilla publishes arm64 |
| Firefox policies + bookmarks | ✅ JSON, arch-agnostic |
| noVNC + websockify + TigerVNC | ✅ apt, multi-arch |
| `cbsoc-status.timer` | ✅ systemd, arch-agnostic |

## Known arm64 exceptions (locked)

Documented in `.cursor/rules/cyberblue-multi-arch-policy.mdc`. As of 2026-04-18:

1. **Fleet stack** (`fleetdm/fleet`, `fleet-redis`, `fleet-mysql`) — amd64-only upstream images. Loaded only under the `amd64` compose profile; arm64 installs skip Fleet entirely and use Velociraptor for endpoint management.
2. **Shuffle `tenzir` integration image** (`frikky/shuffle:tenzir`) — amd64-only. `tenzir-node` container will be in a restart loop on arm64; other Shuffle actions are unaffected. This is an opt-in Shuffle integration, not a core service.
3. **`sysmonforlinux`** (Microsoft) — amd64 deb only. `install.sh` skips on arm64 with a message. Use auditd / Wazuh rules as the arm64 equivalent.
4. **`zui`** (Zui Labs desktop GUI) — amd64 deb only. `install.sh` skips on arm64. Zed lake CLI (`zq`) is still available for arm64.

## Verification commands (quick smoke)

Run on any installed host to confirm arm64 health (all should return `aarch64`
or success codes):

```bash
# Host arch
dpkg --print-architecture          # arm64
uname -m                           # aarch64

# Container stack up (expect 25+ on arm64, 27+ on amd64 with Fleet)
sudo docker compose ps | grep -c Up

# Portal reachable
curl -sk -o /dev/null -w '%{http_code}\n' https://localhost:5443/   # 200

# Wazuh indexer reachable (401 is OK — means auth is live)
curl -sk -o /dev/null -w '%{http_code}\n' https://localhost:9200/   # 200 or 401

# Native toolkit arch sanity — spot-check patched binaries
file $(command -v chainsaw hayabusa stratus nuclei) | grep -c aarch64  # 4 on arm64

# Desktop UX layer
systemctl is-active novnc.service
systemctl is-active cbsoc-status.timer
```

## Known arm64 build-time cost

- **Wazuh image rebuild** adds ~20-25 minutes to a first install because the
  upstream images don't publish arm64 manifests yet. `cyberblue_install.sh`
  triggers this automatically; subsequent re-installs reuse the locally
  cached images and are fast. Monitor with
  `sudo docker image ls | grep wazuh/`.
- **NetExec (`nxc`) compile** adds ~2-3 minutes on arm64 because `aardwolf`
  and `pcapy-ng` don't publish arm64 wheels — pipx builds them from source
  using the Rust toolchain and libpcap headers that `install.sh` pre-installs.

## Building an ARM64 ISO

ISO build plan (Cubic vs live-build decision, dual-arch matrix, signing) is
tracked separately. See `.cursor/plans/` for the current ISO plan draft and
`.cursor/rules/cyberblue-iso-build-standards.mdc` for the pre-ISO
acceptance checklist.
