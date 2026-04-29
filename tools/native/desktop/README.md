# CyberBlueSOC · Desktop UX Layer

This folder adds the "**Kali-for-Blue-Teams**" desktop experience on top of the
Docker stack and native toolkit. It is what turns the host into a usable SOC
workstation: a branded welcome dashboard, an XFCE application menu grouped by
SOC capability, a single-command `cyberblue` CLI, a background
status-refresher, and a preconfigured Firefox homepage.

It is wired into `tools/native/install.sh` and runs automatically whenever a
desktop environment is detected. It can also be installed on its own:

```bash
sudo bash tools/native/desktop/install-desktop.sh
```

## What ships

| Path installed to | Source | Purpose |
|---|---|---|
| `/usr/local/share/cyberbluesoc/welcome/` | `welcome/*` | Branded welcome dashboard (HTML + CSS + JS) |
| `/usr/local/bin/cyberblue` | `bin/cyberblue` | Single entry-point CLI (status / up / urls / doctor / open …) |
| `/usr/local/bin/cbsoc-term-run` | `bin/cbsoc-term-run` | Opens a branded terminal and runs `<tool> --help` |
| `/usr/local/bin/cbsoc-status-refresh` | `bin/cbsoc-status-refresh` | Regenerates `status.js` for the dashboard |
| `/usr/local/bin/cbsoc-url-dispatch` | generated | Handler for `cbsoc-app://` / `cbsoc-cli://` URIs fired by the dashboard |
| `/usr/local/bin/cbsoc-seed-firefox-logins` | `bin/cbsoc-seed-firefox-logins` | Drives headless Firefox via Marionette to (a) pre-save every SOC tool's credentials so login pages autofill, and (b) install a permanent cert exception for every HTTPS tool so the "potential security risk" page never appears |
| `/usr/local/share/cyberbluesoc/firefox-logins.json` | `firefox-logins.json` | Source-of-truth credential catalog used by the seeder |
| `/usr/local/share/cyberbluesoc/firefox-cert-exceptions.json` | `firefox-cert-exceptions.json` | Extra HTTPS origins (no-creds tools like Portainer + the Portal) the seeder pre-trusts |
| `~/.mozilla/firefox/cyberbluesoc.default/logins.json` | generated at install | Seeded Firefox password store (9 SOC tools) |
| `~/.mozilla/firefox/cyberbluesoc.default/cert_override.txt` | generated at install | Pre-installed cert exceptions for all HTTPS tools — same file Firefox writes when a user clicks *Accept the Risk and Continue* |
| `/etc/systemd/system/cbsoc-status.{service,timer}` | `systemd/*` | Refresh `status.js` every 30s |
| `/usr/share/applications/cyberbluesoc-*.desktop` | generated (×67) | Per-tool application entries — web, GUI, CLI |
| `/usr/share/desktop-directories/cyberbluesoc-*.directory` | generated (×20) | Category headers for the XFCE menu |
| `/etc/xdg/menus/applications-merged/cyberbluesoc-applications.menu` | generated | XFCE menu tree (merged into `xfce-applications.menu`) |
| `/etc/firefox/policies/policies.json` | generated | Firefox homepage + bookmarks toolbar |
| `~/Desktop/0[1-6]-*.desktop` | generated | Six curated desktop shortcuts (Dashboard, Wazuh, TheHive, Velociraptor, Wireshark, Terminal) — XFCE default File System / Home / Removable icons are also disabled at install time |

## The welcome dashboard

Opens at `file:///usr/local/share/cyberbluesoc/welcome/index.html`. Firefox is
configured to use it as the homepage.

- **Top**: brand + host IP + last-refresh timestamp + `N/N services up` pill
  (red / amber / green).
- **Category filter bar**: `All`, `SIEM`, `DFIR`, `Threat Intel`, `SOAR`,
  `IDS / Network`, `Adversary Sim`, `Endpoint Mgmt`, `Utility`,
  `Platform Ops`. Click to filter the SOC Web Tools section.
- **SOC Web Tools**: 16 cards, each with icon, category chip, description,
  live container-state dot, `Creds` button (when known), and an
  `Open ↗` button that pops the tool in a new browser tab.
- **Native Toolkit**: 47 tools in eight groups. GUI-first groups (network,
  disk, memory) render full cards; CLI-only groups (windows-triage, detection
  engineering, malware, IOC) render compact clickable chips. All of them hand
  off to `cbsoc-term-run` via the `cbsoc-cli://` URI scheme, which pops a
  branded terminal pre-printed with `<tool> --help`.

The dashboard loads `status.js` (auto-generated) with a `<script>` tag — no
`fetch()`, no CORS headaches on `file://`. The page also auto-reloads every
60s so it re-reads `status.js`.

## The `cyberblue` CLI

```text
Stack control:
  cyberblue status              # pretty-printed `docker ps`
  cyberblue up [standard|full|falco]
  cyberblue down
  cyberblue restart <svc>
  cyberblue logs <svc>
  cyberblue ps
  cyberblue update

Discovery:
  cyberblue urls                # every web UI with its creds
  cyberblue tools [category]    # list native CLI / desktop tools
  cyberblue dashboard           # open the welcome dashboard
  cyberblue portal              # open the legacy tile portal
  cyberblue open <tool>         # e.g. `cyberblue open wazuh`

Info:
  cyberblue version
  cyberblue doctor              # self-check: docker, RAM, ports, …
```

`cyberblue doctor` is the fastest way to triage "is this VM healthy". It
checks for docker / compose, the compose root, the dashboard install, RAM
≥14 GiB, and every SOC tool port listening.

## The XFCE menu

The installer generates a two-level tree under **Applications → CyberBlueSOC**:

```text
CyberBlueSOC
├── 🌐 Web Tools
│   ├── 🛡️ SIEM              → Wazuh
│   ├── 🔍 DFIR              → Velociraptor
│   ├── 🧠 Threat Intel      → MISP, MITRE Navigator
│   ├── 🤖 SOAR              → TheHive, Cortex, Shuffle
│   ├── 📡 IDS / Network     → Arkime, Evebox
│   ├── ♟️ Adversary Sim     → Caldera
│   ├── 💻 Endpoint Mgmt     → FleetDM
│   ├── 🧰 Utilities         → CyberChef
│   └── ⚙️ Platform Ops      → CyberBlue Portal, Portainer, Grafana, CrowdSec
├── ⚙️ Native Toolkit
│   ├── 📡 Network Forensics     → Wireshark · NetworkMiner · tshark · termshark · tcpdump · ngrep · tcpreplay · mitmproxy
│   ├── 💽 Disk Forensics        → Autopsy · fls · mmls · icat · ewfinfo · testdisk · foremost · scalpel · bulk_extractor · binwalk
│   ├── 🧠 Memory Forensics      → vol (Volatility 3) · volshell
│   ├── ⏱️ Timeline / Plaso      → log2timeline · psort
│   ├── 🪟 Windows Triage        → chainsaw · hayabusa · zircolite · regripper · evtx_dump
│   ├── 🧪 Detection Engineering → sigma · yara · nuclei · trivy
│   ├── ☣️ Malware Triage        → radare2 · upx · olevba · pdfid · pdf-parser · capa · floss · clamscan
│   └── 🧰 IOC & Data Utils      → iocextract · hashid · hashdeep · ssdeep · exiftool · hexedit · jq · ripgrep
├── 🎛️ CyberBlueSOC Dashboard   (the welcome page)
├── 🔗 CyberBlue Portal         (the legacy tile portal)
└── ⌨️ CyberBlue CLI            (opens a terminal running `cyberblue help`)
```

Clicking any Web entry opens the URL in the default browser, resolved at
click time from `hostname -I`. Clicking any Native CLI entry pops
`cbsoc-term-run <bin>`.

## Firefox homepage + bookmarks toolbar

`/etc/firefox/policies/policies.json` sets the homepage to the welcome
dashboard and seeds a toolbar with every web UI, grouped by SOC capability.
Users see them as soon as they open Firefox.

## Username / password autofill

When a user clicks a tool in the welcome dashboard (or in the
`Applications → CyberBlueSOC` menu), Firefox opens the tool's login page
with the username + password already filled in. No extensions, no
userscripts — this is Firefox's native password manager firing.

### The catalog — `firefox-logins.json`

Source of truth for every SOC tool's default credentials. Installed at
`/usr/local/share/cyberbluesoc/firefox-logins.json`. The special token
`__IP__` in an `origin` is substituted with the host's primary IPv4 at
seed time.

```json
[
  { "name": "Wazuh",
    "origin":   "https://__IP__:7001",
    "username": "admin",
    "password": "SecretPassword" },
  ...
]
```

### The seeder — `cbsoc-seed-firefox-logins`

We can't write `logins.json` by hand on Ubuntu 24.04: NSS 3.98's
`PK11SDR_Encrypt` segfaults when it has to lazily create the SDR key on a
fresh `key4.db` (reproducible in pure C — see `ENHANCEMENTS.md` #39). We
worked around this by having **Firefox itself** do the encryption, driven
over the Marionette remote protocol:

1. Spawn headless Firefox with `--marionette --remote-allow-system-access`.
2. Connect via `marionette_driver`, switch to the `chrome` context.
3. For each catalog entry, call
   `Services.logins.addLoginAsync(nsILoginInfo)` — the same code path
   that runs when a user clicks *Save login* in the UI.
4. `await Services.logins.initializationPromise` + sleep 2 s to let the
   async writers finish.
5. Send `Marionette:Quit` and wait up to 20 s for Firefox to exit so it
   flushes `logins.json` cleanly.

The seeder is **idempotent**: entries with the same `origin` + `username`
are skipped, so `install-desktop.sh` can run it every time without
creating duplicates.

### Why Marionette instead of `certutil` + direct NSS?

| Approach | Result |
|---|---|
| `certutil -N --empty-password` + Python ctypes → `PK11SDR_Encrypt(NULL, …)` | **Segfaults** inside libnss3 on Ubuntu 24.04 NSS 3.98. Reproducible from C. |
| `ffpass` Python package | Aborts with *"Firefox database appears to be broken. Try to add a password to rebuild it."* — needs the SDR key to already exist. |
| **Firefox + Marionette (chosen)** | Works. Firefox's `LoginManager` knows how to initialise the SDR key on an empty profile. |

### What Firefox actually does at click time

When the user opens e.g. `http://172.31.17.175:7005` (TheHive):

1. The login page loads. Firefox's `LoginManagerChild` scans the DOM for
   username + password fields.
2. It calls `Services.logins.searchLogins({origin: "http://172.31.17.175:7005"})`.
3. That returns the seeded entry → Firefox fills the fields.
4. The user presses Enter. Done.

`signon.autofillForms.http` is set to `true` in the profile's `user.js`
so autofill fires on plain-HTTP origins too (TheHive, Cortex, Caldera,
Grafana, FleetDM, Arkime are HTTP inside the lab).

### Verifying the seed worked

```bash
python3 -c 'import json; d=json.load(open(
  "$HOME/.mozilla/firefox/cyberbluesoc.default/logins.json"));
  print(len(d["logins"]), "logins")'
```

Expected: `9 logins`.

## Self-signed cert exceptions (no more "Potential Security Risk" page)

Half of CyberBlueSOC's web UIs ship behind self-signed TLS — Wazuh,
Velociraptor, MISP, Portainer, the Portal. Out of the box Firefox shows
the "Warning: Potential Security Risk Ahead" interstitial on every one
of them and forces the user through *Advanced → Accept the Risk and
Continue*. We pre-do that step at install time.

### How

Inside the same Marionette session that seeds logins, the seeder also
runs:

1. For every HTTPS origin in `firefox-cert-exceptions.json` *and* every
   HTTPS origin in `firefox-logins.json`, fetch the live leaf cert from
   the running tool with Python's `ssl.get_server_certificate` (no
   verification — that's the whole point).
2. Hand each `(host, port, cert-DER-base64)` triple to a chrome-context
   JS snippet that calls
   `nsICertOverrideService.rememberValidityOverride(host, port, {}, cert, false)`.
3. That's the same call Firefox makes when a user clicks *Accept the
   Risk*. The override is persisted to `cert_override.txt` and the
   profile's `cert9.db`, so it survives Firefox restarts and re-seeding
   is idempotent.

### What's covered

`firefox-cert-exceptions.json` lists the no-creds HTTPS tools (the
ones that don't appear in `firefox-logins.json`):

| Tool | Origin |
|---|---|
| CyberBlue Portal | `https://__IP__:5443` |
| Portainer        | `https://__IP__:9443` |

The seeder also auto-includes every HTTPS origin from
`firefox-logins.json` (Wazuh, Velociraptor, MISP) so credentialled
HTTPS tools get a cert override "for free" without having to be listed
twice.

### Caveat: cert rotation

The override is keyed on `(host, port, cert SHA-256)`. If a tool
regenerates its cert (e.g. a Wazuh re-init), the override invalidates
and the warning comes back. Re-running `install-desktop.sh` re-seeds
against the new cert and clears it.

### Verifying

```bash
cat ~/.mozilla/firefox/cyberbluesoc.default/cert_override.txt
# expect 5 lines (Wazuh, Velociraptor, MISP, Portal, Portainer)
```

## Status refresher

`cbsoc-status.timer` runs `cbsoc-status-refresh` every 30s. The refresher:

1. Reads the primary host IP via `hostname -I`.
2. Walks `docker ps -a` and extracts each container's state + health.
3. Writes a tiny `window.STATUS = {host, ts, containers:{…}}` object to
   `/usr/local/share/cyberbluesoc/welcome/status.js`.

The dashboard `<script src="status.js">` picks this up on page load.

## Adding a new tool

- **Web tool**: add a new entry to `welcome/catalog.js` (`CATALOG.web`) **and**
  a new `_web` line in `install-desktop.sh`. Re-run the installer.
- **Web tool with login** — *also* add an entry to `firefox-logins.json`
  so the seeder pre-saves its credentials. Use `__IP__` for the host.
- **Native GUI tool**: install the binary in `../install.sh`, then add an
  `_gui` line here.
- **Native CLI tool**: install the binary in `../install.sh`, then add a
  `_cli` line here and a matching entry in `welcome/catalog.js`
  (`CATALOG.nativeGroups`).

## Re-running safely

Everything written by `install-desktop.sh` is either:
- a file under `/usr/local/share/cyberbluesoc/`, `/usr/local/bin/`,
  `/usr/share/applications/`, `/usr/share/desktop-directories/`,
  `/etc/xdg/menus/applications-merged/`, `/etc/systemd/system/`
- or a Firefox policy file under `/etc/firefox/policies/`

All of those are overwritten (not merged) on each run, so re-running
`install-desktop.sh` cleanly picks up any changes you've made to files in
this folder.
