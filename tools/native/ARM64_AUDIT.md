# ARM64 support audit — `tools/native/install.sh`

Static audit of every binary / package fetched by
[`install.sh`](./install.sh), showing arm64 support status and any
fix applied to reach parity with amd64. Matches the methodology used
for the Docker-stack audit (`ENHANCEMENTS.md` #50) and the lessons in
`ENHANCEMENTS.md` #52 (post-UTM smoke test).

Methodology:
- Grep `install.sh` for arch-sensitive patterns (`amd64`, `x86_64`,
  `linux-x64`, `x64.tar.gz`, `.exe`, hardcoded GitHub release URLs).
- For each flagged tool, check the upstream GitHub Releases page /
  apt mirror / PyPI for arm64 coverage.
- Classify each tool into one of four buckets:
  - **green** — already arm64-native through apt / pip / pipx / git /
    Docker / pure Python / pure-Go multi-arch release.
  - **fix-url** — upstream ships arm64 binaries but `install.sh`
    hardcoded the amd64 asset name. Fix is a one-line URL tweak.
  - **rebuild** — upstream doesn't publish arm64 prebuilt, but source
    build is practical. Deferred to later phases / opt-in flag.
  - **gap** — no arm64 support upstream; skipped on arm64 with a
    clear message, documented mitigation.

Status: completed **2026-04-18** on `arm64-bringup` branch, before
running `install.sh` on the UTM VM. URL-fix bucket has been applied
to `install.sh` in the same commit as this audit.

## Summary

| Bucket | Count | Action taken |
|---|---|---|
| green | 50 | No change |
| fix-url | 3 | URL fixed via `$CHAINSAW_ARCH`, `$HAYABUSA_ARCH`, `$STRATUS_ARCH` in the top-level arch `case` block |
| rebuild | 1 | `bulk_extractor` — skip on arm64 with explicit message, source build deferred |
| gap | 2 | `sysmonforlinux`, `zui` — locked amd64-only per `cyberblue-multi-arch-policy.mdc` |

Total tools evaluated: **~56**.

## Full inventory

### Section 1/11 — Base toolchain (`apt`)

| Tool | arm64 | Notes |
|---|---|---|
| curl, wget, jq, ripgrep, unzip, p7zip-full, git | green | apt, multi-arch |
| ca-certificates, gnupg, lsb-release, pkg-config, build-essential | green | apt, multi-arch |
| python3, python3-pip, python3-venv | green | apt, multi-arch |
| yara | green | apt, multi-arch |

### Section 2/11 — Nuclei

| Tool | Status | Asset URL pattern | Notes |
|---|---|---|---|
| `nuclei` | green | `nuclei_${VER}_linux_${GO_ARCH}.zip` | `GO_ARCH` is `amd64` / `arm64` set by the top-level `case "$ARCH"` block; arm64 release published |

### Section 3/11 — Trivy

| Tool | Status | Notes |
|---|---|---|
| `trivy` | green | Installed via Aqua's apt repo (`aquasecurity.github.io/trivy-repo/deb`) — repo publishes `arm64` Packages.gz alongside `amd64` |

### Section 4/11 — Volatility 3

| Tool | Status | Notes |
|---|---|---|
| `vol`, `volshell` | green | `pip3 install volatility3` — pure Python, arch-agnostic |

### Section 5/11 — plaso (log2timeline)

| Tool | Status | Notes |
|---|---|---|
| `log2timeline`, `psort` | green | Shipped as Docker wrappers that pull `log2timeline/plaso:latest` at run time. The upstream image tag ships `linux/amd64` only, but Docker Desktop on Apple Silicon runs it under emulation transparently. Acceptable since users only invoke it for ad-hoc triage, not a hot path. Flag as a soft-gap — re-evaluate if plaso adds an arm64 manifest |

### Section 6/11 — sigma-cli

| Tool | Status | Notes |
|---|---|---|
| `sigma` | green | `pip3 install pysigma-cli` — pure Python |

### Section 7/11 — Network forensics (apt)

| Tool | Status | Notes |
|---|---|---|
| `wireshark-common`, `tshark`, `tcpdump`, `tcpreplay`, `ngrep`, `termshark`, `mitmproxy` | green | apt, multi-arch |
| `net-tools`, `dnsutils`, `whois` | green | apt, multi-arch |
| `nmap`, `masscan` | green | apt, multi-arch |
| `wireshark` (GUI) | green | apt, multi-arch; installed only when a DE is detected |

### Section 8/11 — Disk / dead-box forensics

| Tool | Status | Notes |
|---|---|---|
| `sleuthkit` (fls, mmls, icat), `afflib-tools`, `ewf-tools` | green | apt, multi-arch |
| `testdisk`, `foremost`, `scalpel` | green | apt, multi-arch |
| `libimage-exiftool-perl`, `hashdeep`, `ssdeep` | green | apt, multi-arch |
| `hexedit`, `bsdmainutils`, `dc3dd` | green | apt, multi-arch |
| `bulk_extractor` | **rebuild** | Upstream v2.1.1 release has **no binary assets**; v2.0.2 ships `bulk_extractor-linux-x86_64.zip` only. Script now gates the download behind `[ "$ARCH" = "amd64" ]` and prints a clear "prebuilt binary is amd64-only; source build deferred on $ARCH" on arm64. Source build via autotools works on arm64 (~15 min) — deferred to a future opt-in flag |

### Section 9/11 — Windows artifact triage

| Tool | Status | Change | Notes |
|---|---|---|---|
| `chainsaw` | **fix-url** | **APPLIED** (this phase) | Upstream v2.14.1 publishes `chainsaw_aarch64-unknown-linux-gnu.tar.gz`. Script now uses `$CHAINSAW_ARCH` for URL and binary find-pattern |
| `hayabusa` | **fix-url** | **APPLIED** (this phase) | Upstream v3.8.1 publishes `hayabusa-3.8.1-lin-aarch64-gnu.zip`. Script now uses `$HAYABUSA_ARCH` |
| `zircolite` | green | `git clone` + `pip install -r requirements.txt` — pure Python via wrapper |
| `regripper` | green | apt, multi-arch |
| `python-evtx`, `evtx` | green | pip, arch-agnostic |

### Section 10/11 — Malware / file triage

| Tool | Status | Notes |
|---|---|---|
| `binwalk`, `radare2`, `upx-ucl` | green | apt, multi-arch |
| `oletools` (olevba, oleid, rtfobj) | green | pip, pure Python |
| `pdfid`, `pdf-parser` | green | Didier Stevens Python scripts (zip from didierstevens.com), arch-agnostic |
| `flare-capa`, `flare-floss` | green | pip, pure Python + bundled rule packs |
| `clamav`, `clamav-daemon` | green | apt, multi-arch |

### Section 11/11 — IOC utils, NetworkMiner, Autopsy

| Tool | Status | Notes |
|---|---|---|
| `iocextract`, `hashid`, `tldextract` | green | pip, pure Python |
| `dnstwist` | green | pip, pure Python |
| `pyhindsight` + `ccl_chromium_reader` | green | pip, pure Python (ccl_chromium_reader installed from GitHub) |
| `networkminer` | green | Runs the `.NET` assembly via `mono` (mono-runtime / mono-devel are multi-arch in apt). `.NET` assemblies are architecture-independent bytecode |
| `autopsy` | soft-gap | apt package unavailable on Ubuntu 24.04 for both amd64 and arm64; script swallows the error with an "unavailable on this release, skipping" message. Arch-agnostic gap, not an arm64 specific issue |

### Section 12/17 — Detection rule packs

| Target | Status | Notes |
|---|---|---|
| `/opt/sigma-rules` (SigmaHQ) | green | `git clone` — YAML content, arch-agnostic |
| `/opt/yara-rules` (Neo23x0 signature-base) | green | `git clone` — YARA text rules, arch-agnostic |
| `cyberblue-rules` wrapper | green | POSIX shell |

### Section 13/17 — Adversary simulation

| Tool | Status | Change | Notes |
|---|---|---|---|
| Atomic Red Team (`/opt/atomic-red-team`) | green | | `git clone` of the test corpus (YAML), arch-agnostic |
| `atomic-list` wrapper | green | | POSIX shell |
| `pwsh` + Invoke-AtomicRedTeam module | green | | Installed only when `pwsh` is present; Microsoft publishes `powershell-7.x-linux-arm64.tar.gz` and `powershell_*_arm64.deb`. Script doesn't install pwsh itself — just consumes it when present |
| `stratus` (Stratus Red Team) | **fix-url** | **APPLIED** (this phase) | Upstream v2.31.0 publishes `stratus-red-team_Linux_arm64.tar.gz`. Script now uses `$STRATUS_ARCH` |
| `nxc` / NetExec | green | | `pipx install git+https://github.com/Pennyw0rth/NetExec` — pure Python |

### Section 14/17 — Beaconing / traffic (Maltrail)

| Tool | Status | Notes |
|---|---|---|
| `maltrail-sensor`, `maltrail-server` | green | `git clone` + `pip install -r requirements.txt` — pure Python |

### Section 15/17 — Cloud security (Prowler)

| Tool | Status | Notes |
|---|---|---|
| `prowler` | green | `pipx install prowler` — pure Python |

### Section 16/17 — Linux endpoint telemetry (Sysmon for Linux)

| Tool | Status | Change | Notes |
|---|---|---|---|
| `sysmon` (Sysmon for Linux) | **gap** | **APPLIED** (this phase) | Microsoft ships `sysmonforlinux` amd64 only on `packages.microsoft.com` (HTTP 404 for arm64). Script now explicitly short-circuits on arm64 with "amd64-only upstream; skipped on $ARCH (mitigation: Falco + auditd)". Matches the locked exception in `cyberblue-multi-arch-policy.mdc` |

### Section 17/17 — Brim / Zui

| Tool | Status | Change | Notes |
|---|---|---|---|
| `zui` (Brim) | **gap** | **APPLIED** (this phase) | Upstream brimdata publishes `zui_${VER}_amd64.deb` for Linux but no linux arm64 `.deb`. Upstream does ship `Zui-${VER}-arm64.dmg` for macOS — Electron builds for Linux arm64 are not yet produced. Script now short-circuits on arm64 with "skipped on $ARCH (upstream publishes Linux .deb for amd64 only; use zeek-cli / zeek-cut / tshark for pcap pivoting on arm64)". Matches the locked exception in `cyberblue-multi-arch-policy.mdc` |

### Desktop UX installer hand-off

| Target | Status | Notes |
|---|---|---|
| `tools/native/desktop/install-desktop.sh` | (out of scope for this audit) | See `tools/native/desktop/ARM64_AUDIT.md` produced in Phase 3 of the arm64 plan |

## Summary of changes made in this phase

The following changes were applied to `install.sh` in the same commit
as this audit:

1. **Top-level arch case block** extended with three new variables:
   `CHAINSAW_ARCH`, `HAYABUSA_ARCH`, `STRATUS_ARCH` (populated per
   `$ARCH = amd64 | arm64`). Single source of truth — every binary
   download in the script references one of these variables rather
   than hardcoding an architecture string.

2. **Chainsaw URL + binary find-pattern** now use
   `${CHAINSAW_ARCH}` (= `aarch64-unknown-linux-gnu` on arm64).

3. **Hayabusa URL + binary find-pattern** now use
   `${HAYABUSA_ARCH}` (= `lin-aarch64-gnu` on arm64).

4. **Stratus Red Team URL** now uses `${STRATUS_ARCH}` (=
   `Linux_arm64` on arm64).

5. **bulk_extractor prebuilt download** gated behind
   `[ "$ARCH" = "amd64" ]` with an informative "source build
   deferred on $ARCH" message on arm64.

6. **sysmonforlinux** short-circuited on non-amd64 with a clear
   message pointing at the Falco + auditd mitigation.

7. **Zui** short-circuited on non-amd64 with a clear message
   pointing at the zeek-cli / zeek-cut / tshark workflow.

Runtime impact on arm64: expected zero fatal errors. Every tool is
either installed natively, or skipped with a clear message.
Re-evaluate plaso (Docker amd64 manifest) and bulk_extractor (source
build opt-in) in a future iteration once the arm64 line stabilises.

## Verification plan

This audit is static; dynamic verification happens in **Phase 4** of
the `arm64_dual-test_full_parity_plan`, which runs
`sudo bash tools/native/install.sh` on the UTM VM and validates the
acceptance gate:

- ≥ 90 % of tools in the final `==> Done. Installed:` summary block
  resolve via `command -v`
- Every "green" / "fix-url" tool launches with `--version` / `--help`
- "gap" / "rebuild" tools print the expected "skipped on $ARCH"
  message, not a silent failure

If Phase 4 uncovers new arm64 issues, this document is the canonical
place to record them.
