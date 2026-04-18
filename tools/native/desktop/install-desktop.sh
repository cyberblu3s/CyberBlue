#!/usr/bin/env bash
#
# install-desktop.sh
# ------------------
# Wires the CyberBlueSOC "UX layer" onto the host:
#
#   1. Installs the welcome dashboard to /usr/local/share/cyberbluesoc/welcome/
#   2. Installs /usr/local/bin/cyberblue      (one-stop CLI)
#   3. Installs /usr/local/bin/cbsoc-term-run (terminal launcher helper)
#   4. Installs /usr/local/bin/cbsoc-status-refresh + systemd timer (every 30s)
#   5. Registers cbsoc-app:// and cbsoc-cli:// URI schemes so the welcome
#      dashboard chips/cards can launch native apps via xdg-open.
#   6. Generates XFCE application-menu entries grouping *every* tool by SOC
#      category — web tools at the top, native GUI apps, then native CLI.
#   7. Seeds a shared Firefox homepage + bookmarks pointing at the dashboard
#      and every web UI.
#   8. Drops two desktop shortcuts (dashboard + portal).
#
# Safe to re-run. Idempotent. Requires root (uses /usr/local/* and /etc/).
#
# Called automatically from tools/native/install.sh when a desktop environment
# is detected. Can also be run on its own:
#
#   sudo bash tools/native/desktop/install-desktop.sh

set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "install-desktop.sh: must be run as root (use sudo)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -z "$TARGET_HOME" ]] && TARGET_HOME="/home/$TARGET_USER"

SHARE_DIR="/usr/local/share/cyberbluesoc"
WELCOME_DIR="$SHARE_DIR/welcome"
ICON_DIR="$SHARE_DIR/icons"
BIN_DIR="/usr/local/bin"
APPS_DIR="/usr/share/applications"
DIRS_DIR="/usr/share/desktop-directories"
MENUS_DIR="/etc/xdg/menus/applications-merged"
SYSD_DIR="/etc/systemd/system"

echo "==> CyberBlueSOC desktop layer → target user: $TARGET_USER ($TARGET_HOME)"

# ---------------------------------------------------------------- 1. files

install -d -m 0755 "$WELCOME_DIR" "$ICON_DIR" "$APPS_DIR" "$DIRS_DIR" "$MENUS_DIR"

echo "==> Installing welcome dashboard → $WELCOME_DIR"
install -m 0644 "$SCRIPT_DIR/welcome/index.html"   "$WELCOME_DIR/index.html"
install -m 0644 "$SCRIPT_DIR/welcome/style.css"    "$WELCOME_DIR/style.css"
install -m 0644 "$SCRIPT_DIR/welcome/app.js"       "$WELCOME_DIR/app.js"
install -m 0644 "$SCRIPT_DIR/welcome/catalog.js"   "$WELCOME_DIR/catalog.js"
install -m 0644 "$SCRIPT_DIR/welcome/status.js"    "$WELCOME_DIR/status.js"
install -m 0644 "$SCRIPT_DIR/welcome/logo.svg"     "$WELCOME_DIR/logo.svg"
install -m 0644 "$SCRIPT_DIR/welcome/logo.svg"     "$ICON_DIR/cyberbluesoc.svg"

echo "==> Installing CLI tools → $BIN_DIR"
install -m 0755 "$SCRIPT_DIR/bin/cyberblue"               "$BIN_DIR/cyberblue"
install -m 0755 "$SCRIPT_DIR/bin/cbsoc-term-run"          "$BIN_DIR/cbsoc-term-run"
install -m 0755 "$SCRIPT_DIR/bin/cbsoc-status-refresh"    "$BIN_DIR/cbsoc-status-refresh"
install -m 0755 "$SCRIPT_DIR/bin/cbsoc-seed-firefox-logins" "$BIN_DIR/cbsoc-seed-firefox-logins"
install -m 0644 "$SCRIPT_DIR/firefox-logins.json"         "$SHARE_DIR/firefox-logins.json"
install -m 0644 "$SCRIPT_DIR/firefox-cert-exceptions.json" "$SHARE_DIR/firefox-cert-exceptions.json"

# ---------------------------------------------------------------- 1b. branded wallpaper
#
# Install the CyberBlueSOC wallpaper to /usr/share/backgrounds/cyberbluesoc/
# and seed the XFCE desktop config with it — but only if no wallpaper config
# exists yet. If iso/scripts/buildbox-bootstrap.sh already wrote the xml
# (AWS/ISO path), we leave that alone. The icons-hide step later merges
# into whatever config is present, so both code paths converge.
#
# The asset ships inside the repo at tools/native/desktop/branding/ so a
# standalone clone + `sudo bash install-desktop.sh` on any XFCE host
# produces the branded look without extra files.

WALLPAPER_SRC="$SCRIPT_DIR/branding/cyberbluesoc-wallpaper.png"
WALLPAPER_DST_DIR="/usr/share/backgrounds/cyberbluesoc"
WALLPAPER_DST="$WALLPAPER_DST_DIR/cyberbluesoc-wallpaper.png"
if [[ -f "$WALLPAPER_SRC" ]]; then
  echo "==> Installing CyberBlueSOC wallpaper → $WALLPAPER_DST"
  install -d -m 0755 "$WALLPAPER_DST_DIR"
  install -m 0644 "$WALLPAPER_SRC" "$WALLPAPER_DST"
  # Also ship the logo next to it so the welcome dashboard / about dialogs
  # can pick it up by path if they want a raster.
  if [[ -f "$SCRIPT_DIR/branding/cyberbluesoc-logo.png" ]]; then
    install -m 0644 "$SCRIPT_DIR/branding/cyberbluesoc-logo.png" \
      "$WALLPAPER_DST_DIR/cyberbluesoc-logo.png"
  fi
  XFCE_DESKTOP_XML_INIT="$TARGET_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
  if [[ ! -f "$XFCE_DESKTOP_XML_INIT" ]]; then
    install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_USER" \
      "$(dirname "$XFCE_DESKTOP_XML_INIT")"
    cat > "$XFCE_DESKTOP_XML_INIT" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="$WALLPAPER_DST"/>
        </property>
      </property>
      <property name="monitor0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="last-image" type="string" value="$WALLPAPER_DST"/>
        </property>
      </property>
    </property>
  </property>
</channel>
XML
    chown "$TARGET_USER:$TARGET_USER" "$XFCE_DESKTOP_XML_INIT"
    chmod 0644 "$XFCE_DESKTOP_XML_INIT"
  fi
else
  echo "==> Wallpaper asset missing ($WALLPAPER_SRC); skipping wallpaper install."
fi

# ---------------------------------------------------------------- 2. systemd

echo "==> Installing status-refresh systemd timer"
install -m 0644 "$SCRIPT_DIR/systemd/cbsoc-status.service" "$SYSD_DIR/cbsoc-status.service"
install -m 0644 "$SCRIPT_DIR/systemd/cbsoc-status.timer"   "$SYSD_DIR/cbsoc-status.timer"
systemctl daemon-reload
systemctl enable --now cbsoc-status.timer >/dev/null
systemctl start cbsoc-status.service >/dev/null || true

# ---------------------------------------------------------------- 3. URI handlers
#
# cbsoc-app:// and cbsoc-cli:// are custom URI schemes we register via xdg-mime.
# The welcome dashboard fires them when a user clicks a tool chip / card, and
# the .desktop handlers route them through the same cbsoc-term-run helper.

echo "==> Registering cbsoc-app:// and cbsoc-cli:// URI handlers"

cat > "$APPS_DIR/cyberbluesoc-app-launcher.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=CyberBlueSOC App Launcher
Exec=/usr/local/bin/cbsoc-url-dispatch %u
Icon=cyberbluesoc
NoDisplay=true
MimeType=x-scheme-handler/cbsoc-app;x-scheme-handler/cbsoc-cli;
Categories=Utility;
EOF

# Tiny dispatcher: rewrites cbsoc-app://wireshark → /usr/bin/wireshark &
# and cbsoc-cli://tshark → cbsoc-term-run tshark.
cat > "$BIN_DIR/cbsoc-url-dispatch" <<'EOF'
#!/usr/bin/env bash
# cbsoc-url-dispatch — handles cbsoc-app:// and cbsoc-cli:// URIs
# fired by the welcome dashboard. See tools/native/desktop/install-desktop.sh.
url="${1:-}"
scheme="${url%%:*}"
target="${url#*://}"
target="${target%%/*}"
target="${target%%\?*}"
# url-decode %xx
target="$(printf '%b' "${target//%/\\x}")"

case "$scheme" in
  cbsoc-app)
    if command -v "$target" >/dev/null 2>&1; then
      setsid "$target" </dev/null >/dev/null 2>&1 &
    else
      notify-send "CyberBlueSOC" "GUI tool '$target' is not installed." 2>/dev/null || true
    fi
    ;;
  cbsoc-cli)
    exec /usr/local/bin/cbsoc-term-run "$target"
    ;;
  *)
    echo "cbsoc-url-dispatch: unknown scheme '$scheme'" >&2
    exit 2
    ;;
esac
EOF
chmod 0755 "$BIN_DIR/cbsoc-url-dispatch"

# Tell xdg the schemes are handled by our .desktop.
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi
sudo -u "$TARGET_USER" -H bash -lc "
  xdg-mime default cyberbluesoc-app-launcher.desktop x-scheme-handler/cbsoc-app 2>/dev/null || true
  xdg-mime default cyberbluesoc-app-launcher.desktop x-scheme-handler/cbsoc-cli 2>/dev/null || true
" || true

# ---------------------------------------------------------------- 4. top-level .desktop entries

echo "==> Writing top-level .desktop launchers (Dashboard + Portal + CLI)"

cat > "$APPS_DIR/cyberbluesoc-welcome.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=CyberBlueSOC Dashboard
GenericName=SOC Welcome Dashboard
Comment=Overview of every SOC web tool and native forensics utility
Exec=xdg-open file://$WELCOME_DIR/index.html
Icon=cyberbluesoc
Terminal=false
Categories=Network;Security;CyberBlueSOC;
StartupNotify=true
EOF

cat > "$APPS_DIR/cyberbluesoc-portal.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=CyberBlue Portal
GenericName=Legacy tile portal
Comment=Open the original CyberBlue Flask portal
Exec=bash -lc 'xdg-open "https://$(hostname -I | awk "{print \$1}"):5443"'
Icon=cyberbluesoc
Terminal=false
Categories=Network;Security;CyberBlueSOC;
EOF

cat > "$APPS_DIR/cyberbluesoc-cli.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=CyberBlue CLI
GenericName=cyberblue help
Comment=Launch the cyberblue command (status/up/urls/…)
Exec=/usr/local/bin/cbsoc-term-run cyberblue help
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;CyberBlueSOC;
EOF

# Plain terminal launcher used as the 6th desktop pin. Separate from
# `cyberbluesoc-cli.desktop` so the desktop slot is "open a shell" not
# "open `cyberblue help`" — analysts use the shell for everything (tail
# logs, run jq over EVE, drive Volatility, …), the help screen is a
# one-time onboarding read.
cat > "$APPS_DIR/cyberbluesoc-terminal.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Terminal
GenericName=Terminal Emulator
Comment=Open a CyberBlueSOC-branded shell (xfce4-terminal)
Exec=xfce4-terminal --title="CyberBlueSOC" --working-directory=/home/ubuntu
Icon=utilities-terminal
Terminal=false
Categories=System;TerminalEmulator;CyberBlueSOC;
EOF

# ---------------------------------------------------------------- 5. SOC category directories

echo "==> Writing category .directory files"

_dir() {
  # $1 filename (no ext)  $2 name  $3 icon
  cat > "$DIRS_DIR/cyberbluesoc-$1.directory" <<EOF
[Desktop Entry]
Type=Directory
Name=$2
Icon=$3
EOF
}
_dir root     "CyberBlueSOC"             "cyberbluesoc"
_dir web      "Web Tools"                "applications-internet"
_dir siem     "SIEM"                     "security-high"
_dir dfir     "DFIR"                     "applications-system"
_dir cti      "Threat Intel"             "applications-science"
_dir soar     "SOAR"                     "applications-accessories"
_dir ids      "IDS / Network"            "network-workgroup"
_dir redteam  "Adversary Sim"            "applications-games"
_dir mgmt     "Endpoint Management"      "computer"
_dir utility  "Utilities"                "applications-utilities"
_dir ops      "Platform Ops"             "preferences-system"
_dir native   "Native Toolkit"           "applications-engineering"
_dir nt-net   "Native · Network Forensics"      "network-wireless"
_dir nt-disk  "Native · Disk Forensics"         "drive-harddisk"
_dir nt-mem   "Native · Memory Forensics"       "face-monkey"
_dir nt-time  "Native · Timeline / Plaso"       "x-office-calendar"
_dir nt-win   "Native · Windows Triage"         "computer"
_dir nt-det   "Native · Detection Engineering"  "applications-development"
_dir nt-mal   "Native · Malware Triage"         "security-low"
_dir nt-ioc   "Native · IOC & Data Utils"       "applications-utilities"
_dir nt-advsim "Native · Adversary Simulation"  "applications-games"
_dir nt-beacon "Native · Beaconing / Traffic"   "network-workgroup"
_dir nt-cloud  "Native · Cloud Security"        "weather-clear"

# ---------------------------------------------------------------- 6. per-tool .desktop files
#
# Web tools: Exec=xdg-open <url>
# GUI natives: pass through to native binary if present
# CLI natives: Exec=cbsoc-term-run <bin>

echo "==> Writing per-tool .desktop files"

_web() {
  # $1 slug $2 Name $3 url-suffix (e.g. 7001/"")  $4 scheme (http/https) $5 cat-tag
  local slug="$1" name="$2" port="$3" scheme="$4" catkey="$5"
  cat > "$APPS_DIR/cyberbluesoc-web-$slug.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
Comment=Open $name in the default browser
Exec=bash -lc 'xdg-open "$scheme://\$(hostname -I | awk "{print \\\$1}"):$port"'
Icon=applications-internet
Terminal=false
Categories=Network;Security;CyberBlueSOC-$catkey;
EOF
}

# slug            Name              port  scheme    catkey
_web wazuh        "Wazuh"           7001  https     siem
_web velociraptor "Velociraptor"    7000  https     dfir
_web misp         "MISP"            7003  https     cti
_web mitre        "MITRE Navigator" 7013  http      cti
_web thehive      "TheHive"         7005  http      soar
_web cortex       "Cortex"          7006  http      soar
_web shuffle      "Shuffle"         3001  http      soar
_web arkime       "Arkime"          7008  http      ids
_web evebox       "Evebox"          7015  http      ids
_web caldera      "Caldera"         7009  http      redteam
_web fleetdm      "FleetDM"         7007  http      mgmt
_web cyberchef    "CyberChef"       7004  http      utility
_web portal       "CyberBlue Portal"  5443 https    ops
_web portainer    "Portainer"         9443 https    ops
_web grafana      "Grafana"           3000 http     ops
_web crowdsec     "CrowdSec Metrics"  6060 http     ops

_gui() {
  # $1 slug $2 Name $3 bin (must exist at install time to be useful)  $4 catkey  $5 icon
  local slug="$1" name="$2" bin="$3" catkey="$4" icon="${5:-applications-system}"
  cat > "$APPS_DIR/cyberbluesoc-gui-$slug.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
Comment=$name (native GUI — CyberBlueSOC toolkit)
TryExec=$bin
Exec=$bin
Icon=$icon
Terminal=false
Categories=Network;Security;CyberBlueSOC-$catkey;
EOF
}

_gui wireshark    "Wireshark"    wireshark    nt-net  wireshark
_gui zui          "Zui (Brim)"   zui          nt-net  network-wireless
_gui networkminer "NetworkMiner" networkminer nt-net  network-wireless
_gui autopsy      "Autopsy"      autopsy      nt-disk drive-harddisk

_cli() {
  # $1 slug $2 Name $3 bin $4 catkey  $5 description
  local slug="$1" name="$2" bin="$3" catkey="$4" desc="$5"
  cat > "$APPS_DIR/cyberbluesoc-cli-$slug.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
Comment=$desc
TryExec=$bin
Exec=/usr/local/bin/cbsoc-term-run $bin
Icon=utilities-terminal
Terminal=false
Categories=System;Security;CyberBlueSOC-$catkey;
EOF
}

# Native · Network Forensics
_cli tshark       "tshark"           tshark       nt-net  "CLI Wireshark for scripts & pipes"
_cli termshark    "termshark"        termshark    nt-net  "Terminal UI for Wireshark"
_cli tcpdump      "tcpdump"          tcpdump      nt-net  "Classic packet sniffer"
_cli ngrep        "ngrep"            ngrep        nt-net  "grep for network traffic"
_cli tcpreplay    "tcpreplay"        tcpreplay    nt-net  "Replay pcap on a live interface"
_cli mitmproxy    "mitmproxy"        mitmproxy    nt-net  "Intercepting HTTP(S) proxy"
_cli nmap         "nmap"             nmap         nt-net  "Host / service / OS / script discovery"
_cli masscan      "masscan"          masscan      nt-net  "Internet-scale port scanner"

# Native · Disk Forensics
_cli fls          "fls (Sleuth Kit)" fls          nt-disk "List files inside a disk image"
_cli mmls         "mmls (Sleuth Kit)" mmls        nt-disk "List partitions in a disk image"
_cli icat         "icat (Sleuth Kit)" icat        nt-disk "Extract file by inode"
_cli ewfinfo      "ewfinfo"          ewfinfo      nt-disk "Metadata for E01 images"
_cli testdisk     "testdisk"         testdisk     nt-disk "Partition recovery"
_cli foremost     "foremost"         foremost     nt-disk "File carver"
_cli scalpel      "scalpel"          scalpel      nt-disk "Fast configurable carver"
_cli bulkext      "bulk_extractor"   bulk_extractor nt-disk "Feature scanner (IPs, emails, URLs)"
_cli binwalk      "binwalk"          binwalk      nt-disk "Firmware & embedded-FS analysis"
_cli dc3dd        "dc3dd"            dc3dd        nt-disk "Forensic dd — hashing, logging, error-handling"

# Native · Memory Forensics
_cli vol          "Volatility 3 (vol)" vol        nt-mem  "Memory image analysis"
_cli volshell     "volshell"         volshell     nt-mem  "Interactive Python shell vs a memory image"

# Native · Timeline / Plaso
_cli log2timeline "log2timeline (plaso)" log2timeline nt-time "Build a super-timeline"
_cli psort        "psort (plaso)"    psort        nt-time "Filter / sort a super-timeline"

# Native · Windows Triage
_cli chainsaw     "chainsaw"         chainsaw     nt-win  "EVTX hunting with Sigma rules"
_cli hayabusa     "hayabusa"         hayabusa     nt-win  "Fast Windows log timeline hunting"
_cli zircolite    "zircolite"        zircolite    nt-win  "Sigma-based detection on EVTX / auditd"
_cli regripper    "regripper"        regripper    nt-win  "Windows registry extraction"
_cli evtxdump     "evtx_dump"        evtx_dump    nt-win  "Dump EVTX records to JSON"

# Native · Detection Engineering
_cli sigma        "sigma CLI"        sigma        nt-det  "Convert Sigma rules to Splunk/ES/etc"
_cli yara         "yara"             yara         nt-det  "Classify malware by pattern"
_cli nuclei       "nuclei"           nuclei       nt-det  "Template-driven vuln/misconfig scanner"
_cli trivy        "trivy"            trivy        nt-det  "CVE / IaC / secrets scanner"
_cli cbsoc-rules  "CyberBlueSOC Rule Packs" cyberblue-rules nt-det "Show installed Sigma + YARA rule paths"

# Native · Malware Triage
_cli radare2      "radare2"          r2           nt-mal  "Reverse-engineering framework (r2)"
_cli upx          "upx"              upx          nt-mal  "Unpack UPX-compressed binaries"
_cli olevba       "olevba"           olevba       nt-mal  "Extract VBA macros from Office docs"
_cli pdfid        "pdfid"            pdfid        nt-mal  "Triage PDF objects (Didier Stevens)"
_cli pdfparser    "pdf-parser"       pdf-parser   nt-mal  "Deep-dive PDF structure (Didier Stevens)"
_cli capa         "capa (FLARE)"     capa         nt-mal  "Identify capabilities in an executable"
_cli floss        "floss (FLARE)"    floss        nt-mal  "Deobfuscate strings in malware"
_cli clamscan     "clamscan (ClamAV)" clamscan    nt-mal  "On-demand AV scanner"

# Native · IOC & Data Utilities
_cli iocextract   "iocextract"       iocextract   nt-ioc  "Pull IOCs from any text blob"
_cli hashid       "hashid"           hashid       nt-ioc  "Identify hash algorithms"
_cli hashdeep     "hashdeep"         hashdeep     nt-ioc  "Recursive hashing + audit"
_cli ssdeep       "ssdeep"           ssdeep       nt-ioc  "Fuzzy / piecewise hashing"
_cli exiftool     "exiftool"         exiftool     nt-ioc  "Read/write metadata from ~any file"
_cli hexedit      "hexedit"          hexedit      nt-ioc  "Interactive hex editor"
_cli jq           "jq"               jq           nt-ioc  "JSON query/transform"
_cli ripgrep      "ripgrep (rg)"     rg           nt-ioc  "Ludicrously fast grep for logs"
_cli dnstwist     "dnstwist"         dnstwist     nt-ioc  "Find squatting / lookalike domains"
_cli hindsight    "hindsight"        hindsight    nt-ioc  "Chrome/Chromium history + artefact parser"

# Native · Adversary Simulation
_cli atomic       "Atomic Red Team (browse)" atomic-list nt-advsim "List Atomic Red Team tests by MITRE ID"
_cli stratus      "Stratus Red Team" stratus      nt-advsim "Cloud-native attack emulation"
_cli netexec      "NetExec (nxc)"    nxc          nt-advsim "CrackMapExec successor — AD/SMB/WinRM/LDAP"

# Native · Beaconing / Traffic
_cli maltrail-sensor "Maltrail Sensor" maltrail-sensor nt-beacon "Known-bad traffic sensor (needs root)"
_cli maltrail-server "Maltrail Server" maltrail-server nt-beacon "Maltrail reporting UI (:8338)"

# Native · Cloud Security
_cli prowler      "Prowler"          prowler      nt-cloud "AWS/Azure/GCP/K8s CSPM scanner"

# ---------------------------------------------------------------- 7. XFCE menu tree

echo "==> Writing XFCE menu tree"

MENU_FILE="$MENUS_DIR/cyberbluesoc-applications.menu"
cat > "$MENU_FILE" <<'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
 "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<!-- Merged into xfce-applications.menu. Adds a top-level CyberBlueSOC menu
     with Web Tools grouped by SOC capability, then Native Toolkit groups. -->
<Menu>
  <Name>Applications</Name>

  <Menu>
    <Name>CyberBlueSOC</Name>
    <Directory>cyberbluesoc-root.directory</Directory>

    <!-- WEB TOOLS (top, most-used) -->
    <Menu>
      <Name>Web Tools</Name>
      <Directory>cyberbluesoc-web.directory</Directory>

      <Menu>
        <Name>SIEM</Name>
        <Directory>cyberbluesoc-siem.directory</Directory>
        <Include><And><Category>CyberBlueSOC-siem</Category></And></Include>
      </Menu>
      <Menu>
        <Name>DFIR</Name>
        <Directory>cyberbluesoc-dfir.directory</Directory>
        <Include><And><Category>CyberBlueSOC-dfir</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Threat Intel</Name>
        <Directory>cyberbluesoc-cti.directory</Directory>
        <Include><And><Category>CyberBlueSOC-cti</Category></And></Include>
      </Menu>
      <Menu>
        <Name>SOAR</Name>
        <Directory>cyberbluesoc-soar.directory</Directory>
        <Include><And><Category>CyberBlueSOC-soar</Category></And></Include>
      </Menu>
      <Menu>
        <Name>IDS / Network</Name>
        <Directory>cyberbluesoc-ids.directory</Directory>
        <Include><And><Category>CyberBlueSOC-ids</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Adversary Sim</Name>
        <Directory>cyberbluesoc-redteam.directory</Directory>
        <Include><And><Category>CyberBlueSOC-redteam</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Endpoint Management</Name>
        <Directory>cyberbluesoc-mgmt.directory</Directory>
        <Include><And><Category>CyberBlueSOC-mgmt</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Utilities</Name>
        <Directory>cyberbluesoc-utility.directory</Directory>
        <Include><And><Category>CyberBlueSOC-utility</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Platform Ops</Name>
        <Directory>cyberbluesoc-ops.directory</Directory>
        <Include><And><Category>CyberBlueSOC-ops</Category></And></Include>
      </Menu>
    </Menu>

    <!-- NATIVE TOOLKIT (below) -->
    <Menu>
      <Name>Native Toolkit</Name>
      <Directory>cyberbluesoc-native.directory</Directory>

      <Menu>
        <Name>Network Forensics</Name>
        <Directory>cyberbluesoc-nt-net.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-net</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Disk Forensics</Name>
        <Directory>cyberbluesoc-nt-disk.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-disk</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Memory Forensics</Name>
        <Directory>cyberbluesoc-nt-mem.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-mem</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Timeline / Plaso</Name>
        <Directory>cyberbluesoc-nt-time.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-time</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Windows Triage</Name>
        <Directory>cyberbluesoc-nt-win.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-win</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Detection Engineering</Name>
        <Directory>cyberbluesoc-nt-det.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-det</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Malware Triage</Name>
        <Directory>cyberbluesoc-nt-mal.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-mal</Category></And></Include>
      </Menu>
      <Menu>
        <Name>IOC &amp; Data Utils</Name>
        <Directory>cyberbluesoc-nt-ioc.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-ioc</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Adversary Simulation</Name>
        <Directory>cyberbluesoc-nt-advsim.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-advsim</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Beaconing / Traffic</Name>
        <Directory>cyberbluesoc-nt-beacon.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-beacon</Category></And></Include>
      </Menu>
      <Menu>
        <Name>Cloud Security</Name>
        <Directory>cyberbluesoc-nt-cloud.directory</Directory>
        <Include><And><Category>CyberBlueSOC-nt-cloud</Category></And></Include>
      </Menu>
    </Menu>

    <!-- Top-level shortcuts (Dashboard + Portal + CLI) -->
    <Include>
      <Filename>cyberbluesoc-welcome.desktop</Filename>
      <Filename>cyberbluesoc-portal.desktop</Filename>
      <Filename>cyberbluesoc-cli.desktop</Filename>
    </Include>
  </Menu>
</Menu>
EOF

# ---------------------------------------------------------------- 8. desktop shortcuts
#
# Curated, opinionated SOC quicklaunch — six icons total, ordered by what
# an analyst clicks every day. Everything else stays one click away in the
# XFCE menu (Applications → CyberBlueSOC) and on the welcome dashboard.
#
# We deliberately do NOT pin the legacy Portal here — the welcome dashboard
# is the new front door. Users who want it can right-click → Add launcher.
#
# Filenames are 01-..06- prefixed so XFCE's alphabetical fallback sort
# matches our intended priority order even when the user resets icon
# positions. The Name= field controls what users see, not the filename.

echo "==> Writing curated desktop shortcuts for $TARGET_USER"

USER_DESKTOP="$TARGET_HOME/Desktop"
install -d -m 0755 -o "$TARGET_USER" -g "$TARGET_USER" "$USER_DESKTOP"

# Wipe any earlier auto-installed shortcut (current + legacy lowercase
# variants from earlier installer revisions). We never touch user-created
# files — only files we know we put there.
LEGACY_DESKTOP_FILES=(
  CyberBlueSOC-Dashboard.desktop
  CyberBlue-Portal.desktop
  cyberblue-portal.desktop
  cyberbluesoc-dashboard.desktop
  firefox.desktop
  portainer.desktop
  terminal.desktop
  wazuh-dashboard.desktop
  thehive.desktop
  velociraptor.desktop
  wireshark.desktop
)
for f in "${LEGACY_DESKTOP_FILES[@]}"; do
  rm -f "$USER_DESKTOP/$f"
done
# Also clear any previous run of the curated set so re-running doesn't
# leave stale entries with mismatched contents.
rm -f "$USER_DESKTOP"/0[0-9]-*.desktop

# Each entry: <number>  <display-name>  <source .desktop in $APPS_DIR>
#  Source files are produced earlier in this same script (steps 4 + 6),
#  so we know they exist and have working Exec= lines.
_pin() {
  local num="$1" label="$2" src="$3"
  local dest="$USER_DESKTOP/${num}-${label// /-}.desktop"
  if [[ ! -f "$APPS_DIR/$src" ]]; then
    echo "   warn: source $APPS_DIR/$src missing — skipping $label"
    return 0
  fi
  install -m 0755 -o "$TARGET_USER" -g "$TARGET_USER" \
    "$APPS_DIR/$src" "$dest"
  if command -v gio >/dev/null 2>&1; then
    # XFCE refuses to launch .desktop files from the desktop folder unless
    # they're marked trusted + their checksum is recorded. Without these
    # two metadata attributes the user sees a "Mark Executable" prompt
    # on every double-click.
    sudo -u "$TARGET_USER" -H bash -lc "
      gio set \"$dest\" metadata::xfce-exe-checksum \"\$(sha256sum \"$dest\" | awk '{print \$1}')\" || true
      gio set \"$dest\" metadata::trusted true || true
    " || true
  fi
}

_pin 01 "Dashboard"     cyberbluesoc-welcome.desktop
_pin 02 "Wazuh"         cyberbluesoc-web-wazuh.desktop
_pin 03 "TheHive"       cyberbluesoc-web-thehive.desktop
_pin 04 "Velociraptor"  cyberbluesoc-web-velociraptor.desktop
_pin 05 "Wireshark"     cyberbluesoc-gui-wireshark.desktop
_pin 06 "Terminal"      cyberbluesoc-terminal.desktop

# ---- hide XFCE's default desktop icons (File System / Home / Removable)
#
# These add zero value on a SOC workstation — the file manager is one
# click away in the panel and the "Home" icon is just clutter. We keep
# Trash because it's harmless and gives users a familiar drop target.
#
# The settings live in the same xfce4-desktop.xml that holds the
# wallpaper config (set up by the buildbox bootstrap), so we MUST merge
# rather than overwrite — losing the wallpaper because we wanted to hide
# an icon would be the dumbest possible regression.

echo "==> Hiding XFCE default desktop icons (File System / Home / Removable)"

XFCE_DESKTOP_XML="$TARGET_HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml"
install -d -m 0700 -o "$TARGET_USER" -g "$TARGET_USER" \
  "$(dirname "$XFCE_DESKTOP_XML")"

if command -v python3 >/dev/null 2>&1; then
  sudo -u "$TARGET_USER" -H python3 - "$XFCE_DESKTOP_XML" <<'PY'
import os, sys, xml.etree.ElementTree as ET

path = sys.argv[1]

# Load existing channel (e.g. wallpaper config) or start a new one. We
# never blow away a populated <channel> — we only inject the
# desktop-icons subtree.
if os.path.exists(path) and os.path.getsize(path) > 0:
    tree = ET.parse(path)
    channel = tree.getroot()
else:
    channel = ET.Element("channel", {"name": "xfce4-desktop", "version": "1.0"})
    tree = ET.ElementTree(channel)

def find_or_create(parent, tag, name, ptype="empty", value=None):
    for child in parent.findall(tag):
        if child.get("name") == name:
            if value is not None:
                child.set("type", ptype)
                child.set("value", value)
            return child
    attrs = {"name": name, "type": ptype}
    if value is not None:
        attrs["value"] = value
    return ET.SubElement(parent, tag, attrs)

icons = find_or_create(channel, "property", "desktop-icons")
fi    = find_or_create(icons,   "property", "file-icons")

# show-* booleans control which xfdesktop "magic" icons appear.
for name, val in [
    ("show-filesystem", "false"),
    ("show-home",       "false"),
    ("show-removable",  "false"),
    ("show-trash",      "true"),
]:
    find_or_create(fi, "property", name, "bool", val)

# Slightly bigger icons + stop xfdesktop showing every file in
# ~/Desktop (we control what's pinned).
find_or_create(icons, "property", "icon-size",       "uint", "56")
find_or_create(icons, "property", "show-thumbnails", "bool", "true")
find_or_create(icons, "property", "single-click",    "bool", "false")
# style=2 = "icons", which is what we want; style=0 = "no icons", style=1 = "minimised app icons".
find_or_create(icons, "property", "style",           "int",  "2")

ET.indent(tree, space="  ")
tree.write(path, encoding="UTF-8", xml_declaration=True)
PY
  chown "$TARGET_USER:$TARGET_USER" "$XFCE_DESKTOP_XML"
  chmod 0644 "$XFCE_DESKTOP_XML"
else
  echo "   warn: python3 missing — leaving XFCE default icons visible."
fi

# Also push the same setting via xfconf-query if XFCE is currently
# running (e.g. live VNC session). xfdesktop normally picks the change
# up on the dbus signal, but we've seen it freeze when the icon set
# changes mid-session — so we follow up with a clean kill+respawn,
# which always renders correctly.
if command -v xfconf-query >/dev/null 2>&1 && pgrep -u "$TARGET_USER" -x xfdesktop >/dev/null 2>&1; then
  for k in show-filesystem show-home show-removable; do
    sudo -u "$TARGET_USER" -H \
      env DISPLAY="${DISPLAY:-:1}" XAUTHORITY="$TARGET_HOME/.Xauthority" \
      xfconf-query -c xfce4-desktop -p "/desktop-icons/file-icons/$k" \
      -s false --create -t bool 2>/dev/null || true
  done
  # Clean restart. SIGUSR1 is documented as "reload" but in practice
  # locks up xfdesktop's icon view when the file set changes underneath
  # it — observed reproducibly on the AWS box. Kill + nohup respawn is
  # boring but works every time.
  pkill -u "$TARGET_USER" -x xfdesktop 2>/dev/null || true
  sleep 1
  sudo -u "$TARGET_USER" -H \
    env DISPLAY="${DISPLAY:-:1}" XAUTHORITY="$TARGET_HOME/.Xauthority" \
    nohup setsid xfdesktop >/tmp/xfdesktop-respawn.log 2>&1 &
  disown 2>/dev/null || true
  sleep 1
  if pgrep -u "$TARGET_USER" -x xfdesktop >/dev/null 2>&1; then
    echo "   ok:  xfdesktop respawned with new icon set"
  else
    echo "   warn: xfdesktop did not respawn — log out / log in to refresh"
  fi
fi

# ---------------------------------------------------------------- 9. Firefox homepage + bookmarks
#
# We set the default homepage via a system-wide policies.json so all users
# (including newly-created ones on the ISO) land on the welcome dashboard.

echo "==> Seeding Firefox policies (homepage + bookmarks)"
FF_POLICY_DIR=""
for d in /etc/firefox/policies /usr/lib/firefox/distribution \
         /etc/firefox-esr/policies /snap/firefox/current/usr/lib/firefox/distribution; do
  if [[ -d "$(dirname "$d")" ]]; then
    FF_POLICY_DIR="$d"
    mkdir -p "$FF_POLICY_DIR"
    break
  fi
done

if [[ -n "$FF_POLICY_DIR" ]]; then
  cat > "$FF_POLICY_DIR/policies.json" <<'EOF'
{
  "policies": {
    "Homepage": {
      "URL": "file:///usr/local/share/cyberbluesoc/welcome/index.html",
      "Locked": false,
      "StartPage": "homepage"
    },
    "FirefoxHome": {
      "Search":    true,
      "TopSites":  false,
      "Highlights": false,
      "Pocket":    false,
      "Snippets":  false
    },
    "DisplayBookmarksToolbar": "always",
    "ManagedBookmarks": [
      { "toolbar_name": "CyberBlueSOC" },
      { "name": "🛡️ Dashboard",          "url": "file:///usr/local/share/cyberbluesoc/welcome/index.html" },
      { "name": "🔐 Credentials",         "url": "file:///usr/local/share/cyberbluesoc/welcome/index.html#credentials" },
      { "name": "🎛️ Legacy Portal",       "url": "https://127.0.0.1:5443" },
      {
        "name": "🔐 SIEM / DFIR",
        "children": [
          { "name": "Wazuh",        "url": "https://127.0.0.1:7001" },
          { "name": "Velociraptor", "url": "https://127.0.0.1:7000" }
        ]
      },
      {
        "name": "🧠 Threat Intel",
        "children": [
          { "name": "MISP",            "url": "https://127.0.0.1:7003" },
          { "name": "MITRE Navigator", "url": "http://127.0.0.1:7013" }
        ]
      },
      {
        "name": "🤖 SOAR",
        "children": [
          { "name": "TheHive", "url": "http://127.0.0.1:7005" },
          { "name": "Cortex",  "url": "http://127.0.0.1:7006" },
          { "name": "Shuffle", "url": "http://127.0.0.1:3001" }
        ]
      },
      {
        "name": "📡 IDS / Network",
        "children": [
          { "name": "Arkime", "url": "http://127.0.0.1:7008" },
          { "name": "Evebox", "url": "http://127.0.0.1:7015" }
        ]
      },
      {
        "name": "♟️ Adversary Sim",
        "children": [
          { "name": "Caldera", "url": "http://127.0.0.1:7009" }
        ]
      },
      {
        "name": "💻 Endpoint",
        "children": [
          { "name": "FleetDM", "url": "http://127.0.0.1:7007" }
        ]
      },
      {
        "name": "⚙️ Platform Ops",
        "children": [
          { "name": "Portainer",  "url": "https://127.0.0.1:9443" },
          { "name": "Grafana",    "url": "http://127.0.0.1:3000" },
          { "name": "CrowdSec",   "url": "http://127.0.0.1:6060/metrics" },
          { "name": "CyberChef",  "url": "http://127.0.0.1:7004" }
        ]
      }
    ]
  }
}
EOF
fi

# ---------------------------------------------------------------- 9b. Firefox password autofill
#
# Give users "click the tool → login form is already filled in" UX by
# having Firefox itself save every CyberBlueSOC credential in its built-in
# password manager. The autofill that fires on page load is then the same
# autofill Firefox runs for any other saved login.
#
# We drive Firefox via the Marionette remote protocol instead of writing
# logins.json by hand because NSS 3.98 on Ubuntu 24.04 segfaults when its
# PK11SDR_Encrypt has to lazily create the SDR key on a fresh key4.db
# (reproducible in pure C — see ENHANCEMENTS.md #39). Firefox's own code
# path handles that case fine, so we let it do the encryption.

echo "==> Seeding Firefox profile with auto-fill credentials"

FF_PROFILE_ROOT="$TARGET_HOME/.mozilla/firefox"
FF_PROFILE_DIR="$FF_PROFILE_ROOT/cyberbluesoc.default"
FF_PROFILES_INI="$FF_PROFILE_ROOT/profiles.ini"

if ! command -v firefox >/dev/null 2>&1; then
  echo "   skip: firefox not installed"
elif pgrep -u "$TARGET_USER" -x firefox >/dev/null 2>&1; then
  echo "   skip: Firefox is running as $TARGET_USER. Close it and re-run:"
  echo "         sudo bash $0"
else
  # marionette_driver pins to its own deps; installing system-wide keeps
  # the cbsoc-seed-firefox-logins shebang working without a virtualenv.
  if ! python3 -c "import marionette_driver" >/dev/null 2>&1; then
    pip3 install --break-system-packages --quiet marionette_driver \
      >/dev/null 2>&1 || echo "   warn: pip install marionette_driver failed"
  fi

  sudo -u "$TARGET_USER" -H install -d -m 0700 "$FF_PROFILE_ROOT"
  sudo -u "$TARGET_USER" -H install -d -m 0700 "$FF_PROFILE_DIR"

  # Seeding is idempotent: on a re-run, addLoginAsync skips entries that
  # already exist (same origin + username), so we can safely invoke this
  # whenever firefox-logins.json changes.
  sudo -u "$TARGET_USER" -H \
    /usr/local/bin/cbsoc-seed-firefox-logins \
      "$FF_PROFILE_DIR" \
      --ip "$(hostname -I | awk '{print $1}')" \
      --creds           "$SHARE_DIR/firefox-logins.json" \
      --cert-exceptions "$SHARE_DIR/firefox-cert-exceptions.json" \
    || echo "   warn: seeding logins failed (see above)"

  # profiles.ini — make our profile the default. We keep this minimal; if
  # the user has other profiles they want, they can add them back via
  # `firefox -P` or about:profiles.
  if [[ ! -f "$FF_PROFILES_INI" ]]; then
    sudo -u "$TARGET_USER" -H tee "$FF_PROFILES_INI" >/dev/null <<'EOF'
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=CyberBlueSOC
IsRelative=1
Path=cyberbluesoc.default
Default=1
EOF
  elif ! grep -q "Path=cyberbluesoc.default" "$FF_PROFILES_INI"; then
    idx="$(grep -c '^\[Profile' "$FF_PROFILES_INI" || echo 0)"
    sudo -u "$TARGET_USER" -H tee -a "$FF_PROFILES_INI" >/dev/null <<EOF

[Profile$idx]
Name=CyberBlueSOC
IsRelative=1
Path=cyberbluesoc.default
Default=1
EOF
  fi

  # Summary: count logins by peeking into whichever store Firefox used.
  seeded="0"
  if [[ -f "$FF_PROFILE_DIR/logins.json" ]]; then
    seeded="$(python3 -c "import json; print(len(json.load(open('$FF_PROFILE_DIR/logins.json'))['logins']))" 2>/dev/null || echo 0)"
  elif [[ -f "$FF_PROFILE_DIR/logins.db" ]]; then
    seeded="$(sqlite3 "$FF_PROFILE_DIR/logins.db" 'SELECT count(*) FROM loginsL' 2>/dev/null || echo 0)"
  fi
  echo "   ok:  profile ready at $FF_PROFILE_DIR"
  echo "   ok:  $seeded logins now stored"
fi

# ---------------------------------------------------------------- 10. refresh caches

echo "==> Refreshing desktop caches"
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -f /usr/share/icons/hicolor 2>/dev/null || true
fi
if command -v xfce4-panel >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  sudo -u "$TARGET_USER" -H DISPLAY="${DISPLAY:-:0}" xfce4-panel --restart >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------- done

echo
echo "==> CyberBlueSOC desktop layer installed."
echo "    Welcome page : file://$WELCOME_DIR/index.html"
echo "    CLI          : cyberblue help"
echo "    Desktop menu : Applications → CyberBlueSOC"
echo
echo "    Next: log out/in (or run 'xfce4-panel --restart') so XFCE picks up"
echo "    the new menu tree."
