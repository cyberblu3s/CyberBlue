# ARM64 support audit — Desktop UX layer

Static audit of the scripts that install the CyberBlueSOC desktop UX
(welcome dashboard, XFCE application menu, Firefox homepage, branded
wallpaper, CLI helpers) for arm64 compatibility. Sibling to
[`tools/native/ARM64_AUDIT.md`](../ARM64_AUDIT.md) (native toolkit
installer).

Scope:
- [`tools/native/desktop/install-desktop.sh`](./install-desktop.sh) (~975 lines)
- [`iso/scripts/buildbox-bootstrap.sh`](../../../../iso/scripts/buildbox-bootstrap.sh) (workspace-level, ships on the ISO)

Methodology: same as the native toolkit audit — grep for
`amd64`, `x86_64`, `x64`, `aarch64`, `arm64`, `dpkg --print-architecture`,
hardcoded `.deb` / `.rpm` filenames, `releases/download` URLs, and
`curl -o` / `wget` asset fetches.

Status: completed **2026-04-18** on `arm64-bringup`, before running the
desktop layer on the UTM VM (Phase 4 of the arm64 plan).

## Summary

| Script | Arch-sensitive patterns | Arm64 blockers |
|---|---|---|
| `install-desktop.sh` | 0 (no binary downloads, no curl/wget) | 0 |
| `iso/scripts/buildbox-bootstrap.sh` | 1 (docker apt repo) — already arm64-safe via `dpkg --print-architecture` | 0 |

**Result: clean.** Both scripts are already architecture-agnostic.
The desktop UX layer is built entirely from:
- apt packages (multi-arch by default on Ubuntu universe),
- Python scripts bundled with the repo (pure Python, arch-agnostic),
- HTML / CSS / JS assets (the welcome dashboard — static content),
- `.desktop` files and `xfconf` XML (text config, arch-agnostic),
- shell wrapper binaries (`cyberblue`, `cbsoc-term-run`, etc. — POSIX shell).

No prebuilt binary is fetched from GitHub Releases, no
`.deb` / `.rpm` is side-loaded, no architecture-gated path exists
except the (already-correct) Docker apt repo line in
`buildbox-bootstrap.sh`.

## `install-desktop.sh` — line-by-line inventory

| Section | Action | Arm64 | Notes |
|---|---|---|---|
| 1. Welcome dashboard files | `install -m 0644` of `welcome/*.html` / `*.css` / `*.js` / `*.svg` | green | Static assets shipped in the repo |
| 1. CLI tools | `install -m 0755 bin/cyberblue`, `bin/cbsoc-term-run`, `bin/cbsoc-status-refresh`, `bin/cbsoc-seed-firefox-logins` | green | All four are POSIX shell scripts |
| 1. Firefox JSON seeds | `install -m 0644 firefox-logins.json`, `firefox-cert-exceptions.json` | green | JSON data |
| **1b. Branded wallpaper** | **NEW (this phase)** — `install -m 0644 branding/cyberbluesoc-wallpaper.png` + (on fresh hosts only) seed `~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml` with wallpaper path | green | PNG asset committed to the repo at `branding/cyberbluesoc-wallpaper.png` (+ logo) so a standalone clone can run `sudo bash install-desktop.sh` and get the branded look without extra files. If `buildbox-bootstrap.sh` already wrote the xml, we leave it — the merge step later harmonises. |
| 2. systemd timer | `cbsoc-status.service` + `.timer` installed, `systemctl enable --now` | green | systemd is arch-agnostic; both units are plain text |
| 3. URI handlers | Writes `cyberbluesoc-app-launcher.desktop` + `cbsoc-url-dispatch` (POSIX shell) | green | Text + shell |
| 4. `cyberblue` CLI dispatch | Shell wrappers + xdg-mime registration | green | Shell + `xdg-mime` (multi-arch apt) |
| 5. Application menu directories | Writes XFCE menu XML + `.directory` / `.desktop` entries per SOC category | green | Text only |
| 6. Per-tool `.desktop` entries | One file per CyberBlueSOC tool (web + native) — all derived from a shell `case` loop | green | Text only |
| 7. XFCE panel pins | `xfce4-panel --add launcher` calls via `xfconf-query` | green | Runtime-only; works on any arch where XFCE runs |
| 8. Hide default desktop icons | Python3 ElementTree merge into `xfce4-desktop.xml` | green | Pure Python |
| 9. Firefox policies | `install -m 0644 policies.json` + `ManagedBookmarks` | green | JSON |
| 10. Desktop shortcuts | `install -m 0755 Dashboard.desktop`, `CyberBlue-Portal.desktop` | green | Text |
| 11. Firefox profile seed | `cbsoc-seed-firefox-logins` runs on first-run; manipulates `logins.json` + `cert9.db` | green | Uses `sqlite3` (multi-arch apt) and `openssl` (multi-arch) |

All fetches of external resources happen elsewhere:
- Firefox itself is installed by `buildbox-bootstrap.sh` (via Mozilla's
  apt repo — see below).
- The welcome dashboard fetches tool logos at runtime from CDNs, which
  are served as architecture-agnostic PNG/SVG.

## `iso/scripts/buildbox-bootstrap.sh` — inventory

| Section | Action | Arm64 | Notes |
|---|---|---|---|
| apt install (line 14-15) | `xfce4 xfce4-goodies xfce4-terminal wget` | green | All multi-arch in Ubuntu universe |
| Firefox via Mozilla apt repo (line 18-29) | `packages.mozilla.org/apt` pinned with `signed-by=/etc/apt/keyrings/packages.mozilla.org.asc` | green | packages.mozilla.org serves `amd64` **and** `arm64` under the `mozilla` suite (verified via `curl -sI https://packages.mozilla.org/apt/dists/mozilla/main/binary-arm64/Packages.gz` → HTTP 200) |
| VNC xstartup (line 31-39) | Writes `~/.vnc/xstartup` with `startxfce4` launcher | green | Text; `startxfce4` is the multi-arch XFCE session launcher |
| Desktop launchers (line 41-68) | Generates `~/Desktop/*.desktop` | green | Text |
| Wallpaper install (line 72-105) | Copies `../branding/cyberbluesoc-wallpaper.png` → `/usr/share/backgrounds/cyberbluesoc/`, seeds `xfce4-desktop.xml` | green | PNG + XML; arch-agnostic |
| TigerVNC + noVNC systemd units (line 113-149) | `vncserver@.service` + `novnc.service` via `websockify` | green | Systemd text; `tigervnc-standalone-server`, `novnc`, `websockify` are multi-arch apt packages |
| Docker install (line 151-166) | Adds `download.docker.com/linux/ubuntu` apt repo with `arch=$(dpkg --print-architecture)` | green | **Already arm64-aware** — uses `dpkg --print-architecture`, exactly matching the pattern mandated by `cyberblue-multi-arch-policy.mdc` |
| CyberBlue clone (line 168-170) | `git clone https://github.com/cyberblu3s/CyberBlue.git` | green | Git |
| VNC / noVNC service enable (line 172-175) | `systemctl enable --now` + `set-default graphical.target` | green | Systemd |

**Verdict: no arm64 blockers anywhere in `buildbox-bootstrap.sh`.**
The script was clearly written with multi-arch in mind (line 157-158
is the textbook arm64-safe Docker apt repo pattern).

## Fixes applied in this phase

Independent of the arm64 audit, Phase 3 also resolves two tracked
defects recorded in `COMPLETED_STEPS.md`:

### 1. Wallpaper asset committed to the repo

Previously the branded wallpaper only existed in the workspace at
`iso/branding/cyberbluesoc-wallpaper.png`, **outside** the
`CyberBlue/` git tree. A fresh `git clone` on a new host could install
the desktop UX but would have no wallpaper file to point at. Fix:

- Committed `cyberbluesoc-wallpaper.png` (1376x768 PNG, 1.1 MB) to
  `CyberBlue/tools/native/desktop/branding/`.
- Committed `cyberbluesoc-logo.png` (760x614 PNG, 91 KB) alongside.
- Added a new **Section 1b — Branded wallpaper** block to
  `install-desktop.sh` that:
  - Copies the PNG to `/usr/share/backgrounds/cyberbluesoc/`.
  - Seeds `xfce4-desktop.xml` with the wallpaper path **only if**
    the file doesn't already exist. If `buildbox-bootstrap.sh` (AWS /
    ISO path) already wrote the xml, we leave it alone — the
    subsequent icons-hide step merges into whatever is there.

Net effect: a bare `git clone CyberBlue && sudo bash install-desktop.sh`
on any XFCE host now produces the full branded look without needing
the iso/ tree present.

### 2. `caldera-autostart.service` path typo

Two files referenced a non-existent `/home/ubuntu/CyberBlueSOCx/`
path (extra `x` suffix, likely a copy-paste artifact). On every install
this baked the broken path into systemd, so the service silently failed
to start Caldera on boot. Fixed in:

- `cyberblue_install.sh` line 964:
  `WorkingDirectory=/home/ubuntu/CyberBlueSOCx` →
  `WorkingDirectory=/home/ubuntu/CyberBlue`
- `fix-docker-external-access.sh` line 276:
  `ExecStart=/home/ubuntu/CyberBlueSOCx/fix-docker-external-access.sh` →
  `ExecStart=/home/ubuntu/CyberBlue/fix-docker-external-access.sh`

Verified with `grep -r CyberBlueSOCx CyberBlue/` — no matches.

## Verification plan

Static audit only. Runtime verification happens in **Phase 4** of the
arm64 full-parity plan:

1. Install XFCE + VNC + noVNC on the UTM VM via
   `iso/scripts/buildbox-bootstrap.sh`.
2. Run `sudo bash tools/native/install.sh` (includes
   `install-desktop.sh` automatically when a DE is detected).
3. Acceptance:
   - Log in via noVNC at `http://192.168.64.2:6080/vnc.html`.
   - Branded wallpaper renders (not default XFCE grey).
   - `file:///usr/local/share/cyberbluesoc/welcome/index.html` loads
     without cert warnings.
   - XFCE "Applications → CyberBlueSOC" menu has 50+ entries.
   - `systemctl status cbsoc-status.timer caldera-autostart.service`
     both report active/enabled (caldera-autostart will
     succeed only if Caldera is installed; otherwise `remain-after-exit`
     keeps the unit green).
   - `cyberblue status` prints container health.
