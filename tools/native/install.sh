#!/usr/bin/env bash
#
# CyberBlueSOC - Native blue-team toolkit installer
#
# Installs SOC tools that belong on the host, not in containers:
#   Vuln / scanning:     nuclei, trivy
#   Memory forensics:    volatility3 (vol, volshell)
#   Timeline / plaso:    log2timeline, psort (Docker wrappers)
#   Detection engines:   sigma-cli, yara
#   Network forensics:   wireshark, tshark, tcpdump, tcpreplay, ngrep,
#                        termshark, mitmproxy, NetworkMiner
#   Disk / dead-box:     sleuthkit, libewf-utils, afflib-tools, testdisk,
#                        foremost, scalpel, bulk-extractor, exiftool,
#                        hashdeep, ssdeep, Autopsy
#   Windows triage:      chainsaw, hayabusa, zircolite, regripper, python-evtx
#   Malware / files:     binwalk, radare2, oletools, pdf-parser, pdfid,
#                        capa, floss, upx, clamav
#   IOC / data utils:    jq, ripgrep, iocextract, hashid
#
# Idempotent: safe to re-run. Skips anything already installed.
# Tested on Ubuntu 22.04 / 24.04 (amd64, arm64).

set -euo pipefail

LOG=/var/log/cyberbluesoc-native-install.log
exec > >(tee -a "$LOG") 2>&1

echo "==> CyberBlueSOC native tools installer - $(date -Is)"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: must run as root (use sudo)"
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  amd64) GO_ARCH="amd64"; ZIRC_ARCH="x64" ;;
  arm64) GO_ARCH="arm64"; ZIRC_ARCH="arm64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

# =============================================================================
# 1/11  Base toolchain (everything below assumes these)
# =============================================================================
echo "==> [1/11] Base toolchain"
apt-get install -y \
  curl wget jq ripgrep unzip p7zip-full git ca-certificates gnupg lsb-release \
  pkg-config build-essential \
  python3 python3-pip python3-venv \
  yara

# =============================================================================
# 2/11  Nuclei
# =============================================================================
echo "==> [2/11] Nuclei"
if ! command -v nuclei >/dev/null 2>&1; then
  NUCLEI_VERSION="$(curl -fsSL https://api.github.com/repos/projectdiscovery/nuclei/releases/latest | jq -r .tag_name | sed 's/^v//')"
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/nuclei.zip" \
    "https://github.com/projectdiscovery/nuclei/releases/download/v${NUCLEI_VERSION}/nuclei_${NUCLEI_VERSION}_linux_${GO_ARCH}.zip"
  unzip -q -o "$TMP/nuclei.zip" -d "$TMP"
  install -m 0755 "$TMP/nuclei" /usr/local/bin/nuclei
  rm -rf "$TMP"
fi
nuclei -version 2>&1 | head -n 1 || true
nuclei -update-templates -silent || true

# =============================================================================
# 3/11  Trivy
# =============================================================================
echo "==> [3/11] Trivy"
if ! command -v trivy >/dev/null 2>&1; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg
  echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/trivy.list
  apt-get update -qq
  apt-get install -y trivy
fi
trivy --version 2>&1 | head -n 1 || true

# =============================================================================
# 4/11  Volatility 3 (system-wide so all users can run it)
# =============================================================================
echo "==> [4/11] Volatility 3"
if ! command -v vol >/dev/null 2>&1; then
  pip3 install --break-system-packages --no-cache-dir volatility3 || true
fi
vol --help 2>&1 | head -n 1 || true

# =============================================================================
# 5/11  plaso (log2timeline) - Docker wrapper, source build is too fragile
# =============================================================================
echo "==> [5/11] plaso (Docker wrapper)"
if ! command -v log2timeline >/dev/null 2>&1; then
  cat <<'WRAP' > /usr/local/bin/log2timeline
#!/usr/bin/env bash
# CyberBlueSOC: Docker wrapper for plaso log2timeline.
exec docker run --rm -it -v "$(pwd):/data" -w /data log2timeline/plaso log2timeline.py "$@"
WRAP
  cat <<'WRAP' > /usr/local/bin/psort
#!/usr/bin/env bash
# CyberBlueSOC: Docker wrapper for plaso psort.
exec docker run --rm -it -v "$(pwd):/data" -w /data log2timeline/plaso psort.py "$@"
WRAP
  chmod +x /usr/local/bin/log2timeline /usr/local/bin/psort
fi
echo "log2timeline + psort (Docker) ready"

# =============================================================================
# 6/11  sigma-cli
# =============================================================================
echo "==> [6/11] sigma-cli"
if ! command -v sigma >/dev/null 2>&1; then
  pip3 install --break-system-packages --no-cache-dir pysigma-cli || true
fi
sigma --help >/dev/null 2>&1 && echo "sigma-cli installed" || true

# =============================================================================
# 7/11  Network forensics toolkit (apt) + Wireshark (replaces the container)
# =============================================================================
echo "==> [7/11] Network forensics (wireshark, tshark, tcpdump, ...)"
# Preseed wireshark-common so non-root users can capture (dumpcap setcap)
echo "wireshark-common wireshark-common/install-setuid boolean true" \
  | debconf-set-selections
apt-get install -y \
  wireshark-common tshark \
  tcpdump tcpreplay ngrep termshark mitmproxy \
  net-tools dnsutils whois \
  nmap masscan
# Add the interactive ubuntu user to the wireshark group so `dumpcap` works
if id ubuntu >/dev/null 2>&1 && getent group wireshark >/dev/null 2>&1; then
  usermod -a -G wireshark ubuntu || true
fi

# Install wireshark GUI only if a display/desktop exists (skip on pure server)
HAS_DESKTOP=no
for pkg in xubuntu-desktop ubuntu-desktop xfce4-session gnome-shell kde-plasma-desktop; do
  if dpkg -s "$pkg" >/dev/null 2>&1; then HAS_DESKTOP=yes; break; fi
done
if [ "$HAS_DESKTOP" = "yes" ]; then
  apt-get install -y wireshark
  echo "    wireshark GUI installed"
else
  echo "    (no desktop detected - installing wireshark GUI skipped; tshark installed)"
fi

# =============================================================================
# 8/11  Disk / dead-box forensics (apt)
# =============================================================================
echo "==> [8/11] Disk forensics (sleuthkit, testdisk, ...)"
apt-get install -y \
  sleuthkit afflib-tools ewf-tools \
  testdisk foremost scalpel \
  libimage-exiftool-perl \
  hashdeep ssdeep \
  hexedit bsdmainutils \
  dc3dd
# bulk-extractor: not in apt on Ubuntu 24.04. Ship a static prebuilt binary
# (built by the upstream project) if not already installed.
if ! command -v bulk_extractor >/dev/null 2>&1; then
  TMP=$(mktemp -d)
  # Upstream releases Linux binaries; fall back silently if unavailable
  if curl -fsSL --connect-timeout 5 -o "$TMP/be.zip" \
      "https://github.com/simsong/bulk_extractor/releases/latest/download/bulk_extractor-linux-x86_64.zip" 2>/dev/null; then
    unzip -q -o "$TMP/be.zip" -d "$TMP" 2>/dev/null && \
      find "$TMP" -type f -name bulk_extractor -perm -u+x \
        -exec install -m 0755 {} /usr/local/bin/bulk_extractor \; 2>/dev/null || true
  fi
  rm -rf "$TMP"
fi
command -v bulk_extractor >/dev/null 2>&1 && echo "    bulk_extractor installed" || \
  echo "    bulk_extractor: skipped (not in apt and no prebuilt binary fetched; build from source if needed)"

# =============================================================================
# 9/11  Windows artifact triage (Chainsaw, Hayabusa, Zircolite, RegRipper)
# =============================================================================
echo "==> [9/11] Windows triage (chainsaw, hayabusa, zircolite, regripper)"

# Chainsaw (single Rust binary)
if ! command -v chainsaw >/dev/null 2>&1; then
  CHAINSAW_VER="$(curl -fsSL https://api.github.com/repos/WithSecureLabs/chainsaw/releases/latest | jq -r .tag_name | sed 's/^v//')"
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/chainsaw.zip" \
    "https://github.com/WithSecureLabs/chainsaw/releases/download/v${CHAINSAW_VER}/chainsaw_x86_64-unknown-linux-gnu.tar.gz" \
    || curl -fsSL -o "$TMP/chainsaw.zip" \
       "https://github.com/WithSecureLabs/chainsaw/releases/download/v${CHAINSAW_VER}/chainsaw_all_platforms+rules+examples.zip"
  # Handle either .tar.gz or .zip gracefully
  if file "$TMP/chainsaw.zip" | grep -q gzip; then
    tar -C "$TMP" -xzf "$TMP/chainsaw.zip"
    BIN="$(find "$TMP" -type f -name chainsaw -perm -u+x | head -n 1 || true)"
  else
    unzip -q -o "$TMP/chainsaw.zip" -d "$TMP"
    BIN="$(find "$TMP" -type f -name 'chainsaw_x86_64-unknown-linux-gnu' | head -n 1 || true)"
    [ -n "$BIN" ] || BIN="$(find "$TMP" -type f -name chainsaw -perm -u+x | head -n 1 || true)"
  fi
  if [ -n "$BIN" ] && [ -f "$BIN" ]; then
    install -m 0755 "$BIN" /usr/local/bin/chainsaw
  else
    echo "    chainsaw binary not found in release, skipping"
  fi
  rm -rf "$TMP"
fi
command -v chainsaw >/dev/null 2>&1 && chainsaw --version 2>&1 | head -n 1 || true

# Hayabusa (single Rust binary; pick the lin-x64-gnu zip, chmod after extract)
if ! command -v hayabusa >/dev/null 2>&1; then
  HAYA_VER="$(curl -fsSL https://api.github.com/repos/Yamato-Security/hayabusa/releases/latest | jq -r .tag_name | sed 's/^v//')"
  TMP=$(mktemp -d)
  if curl -fsSL --connect-timeout 10 -o "$TMP/haya.zip" \
      "https://github.com/Yamato-Security/hayabusa/releases/download/v${HAYA_VER}/hayabusa-${HAYA_VER}-lin-x64-gnu.zip"; then
    unzip -q -o "$TMP/haya.zip" -d "$TMP"
    # Binary inside zip may lack +x; find by name, not by permissions
    BIN="$(find "$TMP" -type f -name 'hayabusa*lin-x64-gnu*' ! -name '*.zip' | head -n 1 || true)"
    [ -z "$BIN" ] && BIN="$(find "$TMP" -type f -name 'hayabusa*' ! -name '*.zip' ! -name '*.md' | head -n 1 || true)"
    if [ -n "$BIN" ]; then
      install -m 0755 "$BIN" /usr/local/bin/hayabusa
      if [ -d "$TMP/rules" ]; then
        rm -rf /opt/hayabusa-rules
        mv "$TMP/rules" /opt/hayabusa-rules
      fi
    fi
  fi
  rm -rf "$TMP"
fi
command -v hayabusa >/dev/null 2>&1 && hayabusa --version 2>&1 | head -n 1 || echo "    hayabusa: skipped"

# Zircolite (not on PyPI under that name; install from source clone into /opt)
if ! command -v zircolite >/dev/null 2>&1; then
  if [ ! -d /opt/zircolite ]; then
    git clone --depth 1 https://github.com/wagga40/Zircolite.git /opt/zircolite 2>/dev/null || true
  fi
  if [ -d /opt/zircolite ]; then
    pip3 install --break-system-packages --no-cache-dir -r /opt/zircolite/requirements.txt 2>/dev/null || true
    cat <<'WRAP' > /usr/local/bin/zircolite
#!/usr/bin/env bash
# CyberBlueSOC: wrapper for Zircolite (SIGMA on EVTX/JSON/auditd).
exec python3 /opt/zircolite/zircolite.py "$@"
WRAP
    chmod +x /usr/local/bin/zircolite
  fi
fi
command -v zircolite >/dev/null 2>&1 && echo "    zircolite ready" || echo "    zircolite: skipped"

# RegRipper (apt) + python-evtx (pip)
apt-get install -y regripper || true
pip3 install --break-system-packages --no-cache-dir python-evtx evtx || true

# =============================================================================
# 10/11  Malware / file triage (apt + pip)
# =============================================================================
echo "==> [10/11] Malware / file triage"
apt-get install -y \
  binwalk radare2 upx-ucl || true
# oletools (pip - provides olevba, oleid, olemap, msodde, rtfobj)
pip3 install --break-system-packages --no-cache-dir oletools || true
# Didier Stevens: pdf-parser.py + pdfid.py (direct download, no apt package).
# URLs have different versions/case, so hardcode the current ones.
TMP=$(mktemp -d)
if ! command -v pdfid >/dev/null 2>&1; then
  if curl -fsSL --connect-timeout 5 -o "$TMP/pdfid.zip" \
      "https://didierstevens.com/files/software/pdfid_v0_2_8.zip"; then
    unzip -q -o "$TMP/pdfid.zip" -d "$TMP" && \
      install -m 0755 "$TMP/pdfid.py" /usr/local/bin/pdfid.py
    cat <<'WRAP' > /usr/local/bin/pdfid
#!/usr/bin/env bash
exec python3 /usr/local/bin/pdfid.py "$@"
WRAP
    chmod +x /usr/local/bin/pdfid
  fi
fi
if ! command -v pdf-parser >/dev/null 2>&1; then
  if curl -fsSL --connect-timeout 5 -o "$TMP/pdf-parser.zip" \
      "https://didierstevens.com/files/software/pdf-parser_V0_7_12.zip"; then
    unzip -q -o "$TMP/pdf-parser.zip" -d "$TMP" && \
      install -m 0755 "$TMP/pdf-parser.py" /usr/local/bin/pdf-parser.py
    cat <<'WRAP' > /usr/local/bin/pdf-parser
#!/usr/bin/env bash
exec python3 /usr/local/bin/pdf-parser.py "$@"
WRAP
    chmod +x /usr/local/bin/pdf-parser
  fi
fi
rm -rf "$TMP"

# capa + floss (Mandiant, pip). Protect against pip3's self-upgrade failure
# by excluding pip from any dependency resolution.
pip3 install --break-system-packages --no-cache-dir --no-deps flare-capa || true
pip3 install --break-system-packages --no-cache-dir flare-capa || true
pip3 install --break-system-packages --no-cache-dir --no-deps flare-floss || true
pip3 install --break-system-packages --no-cache-dir flare-floss || true
# ClamAV - install but keep freshclam disabled-by-default (6 GB db)
apt-get install -y clamav clamav-daemon || true
systemctl stop clamav-freshclam clamav-daemon 2>/dev/null || true
systemctl disable clamav-freshclam clamav-daemon 2>/dev/null || true

# =============================================================================
# 11/11  IOC / data utilities (pip) + NetworkMiner (manual) + Autopsy (deb)
# =============================================================================
echo "==> [11/11] IOC utils, NetworkMiner, Autopsy"
pip3 install --break-system-packages --no-cache-dir iocextract hashid tldextract || true

# dnstwist: domain squat/phish detection (scripting-friendly CLI + JSON).
pip3 install --break-system-packages --no-cache-dir dnstwist || true

# pyhindsight: Chrome/Chromium history + artefact parser (DFIR triage).
# Upstream's setup.py drops hindsight.py (not `hindsight`) into /usr/local/bin
# without the +x bit, so we fix both: +x on the module and a friendly
# short-name symlink. pyhindsight also depends on ccl_chromium_reader, which
# isn't published on PyPI — install from cclgroupltd's GitHub directly.
pip3 install --break-system-packages --no-cache-dir pyhindsight || true
pip3 install --break-system-packages --no-cache-dir \
  git+https://github.com/cclgroupltd/ccl_chromium_reader || true
if [ -f /usr/local/bin/hindsight.py ]; then
  chmod +x /usr/local/bin/hindsight.py /usr/local/bin/hindsight_gui.py 2>/dev/null || true
  ln -sf /usr/local/bin/hindsight.py /usr/local/bin/hindsight
fi

# NetworkMiner (Windows .NET app, runs via Mono)
if [ ! -x /usr/local/bin/networkminer ]; then
  apt-get install -y mono-runtime mono-devel libmono-system-windows-forms4.0-cil || true
  if ! [ -d /opt/NetworkMiner ]; then
    TMP=$(mktemp -d)
    if curl -fsSL -o "$TMP/nm.zip" \
        "https://www.netresec.com/?download=NetworkMiner"; then
      unzip -q -o "$TMP/nm.zip" -d /opt/ || true
      # Move whatever NetworkMiner_* dir it extracted to /opt/NetworkMiner
      NM_DIR="$(find /opt -maxdepth 1 -type d -name 'NetworkMiner*' | head -n 1 || true)"
      if [ -n "$NM_DIR" ] && [ "$NM_DIR" != "/opt/NetworkMiner" ]; then
        mv "$NM_DIR" /opt/NetworkMiner
      fi
      # Make PCAP folders writable so non-root users can save captures
      [ -d /opt/NetworkMiner ] && chmod -R go+rw /opt/NetworkMiner/AssembledFiles /opt/NetworkMiner/Captures 2>/dev/null || true
    fi
    rm -rf "$TMP"
  fi
  if [ -f /opt/NetworkMiner/NetworkMiner.exe ]; then
    cat <<'WRAP' > /usr/local/bin/networkminer
#!/usr/bin/env bash
# CyberBlueSOC: wrapper to run NetworkMiner via Mono.
exec mono /opt/NetworkMiner/NetworkMiner.exe "$@"
WRAP
    chmod +x /usr/local/bin/networkminer
  fi
fi

# Autopsy (Sleuth Kit's Java GUI). Ship as a wrapper around the tarball if
# the distro .deb isn't available for 24.04.
if ! command -v autopsy >/dev/null 2>&1; then
  apt-get install -y autopsy 2>/dev/null || \
    echo "    autopsy: apt package unavailable on this release, skipping (will ship on desktop ISO phase)"
fi

# =============================================================================
# 12/17  Detection rule packs (SigmaHQ rules + Neo23x0 YARA signature-base)
# =============================================================================
# These aren't binaries — they're rule corpora that every detection-engineering
# tool on the box (chainsaw, hayabusa, zircolite, yara, sigma-cli) can point at
# for ready-made coverage. Kept in /opt so they're discoverable and upgradable
# via `cyberblue rules update`.
echo "==> [12/17] Detection rule packs (Sigma, YARA)"

_clone_or_pull() {
  local url="$1" dir="$2"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" pull --ff-only --quiet 2>/dev/null || true
  else
    git clone --depth 1 --quiet "$url" "$dir" 2>/dev/null || true
  fi
}

_clone_or_pull https://github.com/SigmaHQ/sigma.git         /opt/sigma-rules
_clone_or_pull https://github.com/Neo23x0/signature-base.git /opt/yara-rules

# Thin wrapper so users can `cyberblue-rules` to browse the packs.
cat <<'WRAP' > /usr/local/bin/cyberblue-rules
#!/usr/bin/env bash
# CyberBlueSOC: show installed detection rule packs.
set -e
printf "\033[1;36mCyberBlueSOC detection rule packs\033[0m\n"
for pack in \
  "SigmaHQ rules:/opt/sigma-rules/rules" \
  "YARA signature-base:/opt/yara-rules"; do
  name="${pack%%:*}"; path="${pack##*:}"
  if [ -d "$path" ]; then
    count=$(find "$path" -type f \( -name '*.yml' -o -name '*.yar' -o -name '*.yara' \) 2>/dev/null | wc -l)
    printf "  %-22s %s  (%s rules)\n" "$name" "$path" "$count"
  else
    printf "  %-22s %s  (not installed)\n" "$name" "$path"
  fi
done
echo
echo "  Examples:"
echo "    chainsaw hunt evtx/ --sigma /opt/sigma-rules/rules/windows/"
echo "    yara -r /opt/yara-rules/yara/ ./samples/"
echo "    sigma convert -t splunk /opt/sigma-rules/rules/windows/process_creation/"
WRAP
chmod +x /usr/local/bin/cyberblue-rules

# =============================================================================
# 13/17  Adversary simulation & validation (Atomic Red Team, Stratus Red Team,
#        NetExec)
# =============================================================================
# These are the "blue team's sparring partners" — small, safe ways to generate
# real attack telemetry against the SIEM so analysts can verify detections end
# to end instead of waiting for a real incident.
echo "==> [13/17] Adversary simulation (Atomic Red, Stratus Red, NetExec)"

# Atomic Red Team: ~1000 YAML tests keyed to MITRE ATT&CK techniques.
# Ship via Invoke-AtomicRedTeam (PowerShell), which is the upstream recommended
# runner. Cross-platform via pwsh. We just clone the test corpus and wrapper.
if [ ! -d /opt/atomic-red-team ]; then
  git clone --depth 1 --quiet \
    https://github.com/redcanaryco/atomic-red-team.git /opt/atomic-red-team || true
fi
# Invoke-AtomicRedTeam runner (PowerShell module — install only if pwsh exists)
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -Command '
    if (-not (Get-Module -ListAvailable Invoke-AtomicRedTeam)) {
      Install-Module -Name invoke-atomicredteam -Scope AllUsers -Force -AllowClobber
    }' 2>/dev/null || true
fi
# Ship a tiny non-PowerShell wrapper so analysts can browse the atomics on
# Linux even without pwsh: `atomic-list T1059` prints the YAML summary.
cat <<'WRAP' > /usr/local/bin/atomic-list
#!/usr/bin/env bash
# CyberBlueSOC: quick-browse Atomic Red Team techniques by MITRE ID.
set -e
ART=/opt/atomic-red-team/atomics
if [ ! -d "$ART" ]; then
  echo "Atomic Red Team not installed at $ART" >&2; exit 1
fi
if [ -z "${1:-}" ]; then
  ls -1 "$ART" | grep -E '^T[0-9]' | sort
else
  tid=$(echo "$1" | tr '[:lower:]' '[:upper:]')
  if [ -d "$ART/$tid" ]; then
    cat "$ART/$tid/$tid.yaml" 2>/dev/null || ls -la "$ART/$tid"
  else
    echo "no technique $tid"; exit 1
  fi
fi
WRAP
chmod +x /usr/local/bin/atomic-list

# Stratus Red Team: DataDog's cloud-native adversary emulator (AWS/Azure/K8s).
# Single Go binary.
if ! command -v stratus >/dev/null 2>&1; then
  STR_VER="$(curl -fsSL https://api.github.com/repos/DataDog/stratus-red-team/releases/latest | jq -r .tag_name | sed 's/^v//')"
  if [ -n "$STR_VER" ] && [ "$STR_VER" != "null" ]; then
    TMP=$(mktemp -d)
    if curl -fsSL -o "$TMP/s.tgz" \
        "https://github.com/DataDog/stratus-red-team/releases/download/v${STR_VER}/stratus-red-team_Linux_x86_64.tar.gz"; then
      tar -C "$TMP" -xzf "$TMP/s.tgz" 2>/dev/null || true
      BIN="$(find "$TMP" -type f -name stratus -perm -u+x | head -n 1 || true)"
      [ -n "$BIN" ] && install -m 0755 "$BIN" /usr/local/bin/stratus
    fi
    rm -rf "$TMP"
  fi
fi
command -v stratus >/dev/null 2>&1 && echo "    stratus installed" || echo "    stratus: skipped"

# NetExec (the community-maintained successor to CrackMapExec): AD / SMB /
# WinRM / LDAP auth & post-ex framework. The PyPI name only publishes
# pre-releases sporadically, so install straight from the upstream git
# repo — that's also what the project's own README recommends.
if ! command -v nxc >/dev/null 2>&1; then
  apt-get install -y pipx >/dev/null 2>&1 || true
  TARGET_USER="${SUDO_USER:-root}"
  _nxc_install_cmd="pipx install git+https://github.com/Pennyw0rth/NetExec"
  if [ "$TARGET_USER" != "root" ] && id "$TARGET_USER" >/dev/null 2>&1; then
    sudo -u "$TARGET_USER" bash -lc "$_nxc_install_cmd" 2>/dev/null || \
      pip3 install --break-system-packages --no-cache-dir \
        "git+https://github.com/Pennyw0rth/NetExec" || true
    # Symlink from ~/.local/bin into /usr/local/bin so every shell sees it
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    for tool in nxc netexec; do
      if [ -x "$TARGET_HOME/.local/bin/$tool" ]; then
        ln -sf "$TARGET_HOME/.local/bin/$tool" "/usr/local/bin/$tool"
      fi
    done
  else
    pip3 install --break-system-packages --no-cache-dir \
      "git+https://github.com/Pennyw0rth/NetExec" || true
  fi
fi

# =============================================================================
# 14/17  Beaconing / suspicious-traffic detection (Maltrail)
# =============================================================================
# Maltrail is a lightweight sensor+UI that flags traffic to/from domains &
# IPs on public blacklists. Good "known-bad" safety net alongside Suricata.
echo "==> [14/17] Beaconing / traffic detection (Maltrail)"
if [ ! -d /opt/maltrail ]; then
  git clone --depth 1 --quiet https://github.com/stamparm/maltrail.git /opt/maltrail || true
fi
if [ -d /opt/maltrail ]; then
  pip3 install --break-system-packages --no-cache-dir -r /opt/maltrail/requirements.txt 2>/dev/null || true
  # Convenience wrappers. Start the sensor with `cyberblue maltrail start`.
  cat <<'WRAP' > /usr/local/bin/maltrail-sensor
#!/usr/bin/env bash
# CyberBlueSOC: run the Maltrail sensor (needs root for sniffing).
exec python3 /opt/maltrail/sensor.py "$@"
WRAP
  cat <<'WRAP' > /usr/local/bin/maltrail-server
#!/usr/bin/env bash
# CyberBlueSOC: run the Maltrail reporting server (UI on :8338).
exec python3 /opt/maltrail/server.py "$@"
WRAP
  chmod +x /usr/local/bin/maltrail-sensor /usr/local/bin/maltrail-server
fi

# =============================================================================
# 15/17  Cloud security posture (Prowler)
# =============================================================================
# Prowler scans AWS/Azure/GCP/K8s configurations against hundreds of checks
# (CIS, NIST, SOC2, HIPAA). Blue teams increasingly need cloud coverage.
echo "==> [15/17] Cloud security (Prowler)"
if ! command -v prowler >/dev/null 2>&1; then
  apt-get install -y pipx >/dev/null 2>&1 || true
  TARGET_USER="${SUDO_USER:-root}"
  if [ "$TARGET_USER" != "root" ] && id "$TARGET_USER" >/dev/null 2>&1; then
    sudo -u "$TARGET_USER" bash -lc "pipx install prowler" 2>/dev/null || \
      pip3 install --break-system-packages --no-cache-dir prowler || true
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    if [ -x "$TARGET_HOME/.local/bin/prowler" ]; then
      ln -sf "$TARGET_HOME/.local/bin/prowler" /usr/local/bin/prowler
    fi
  else
    pip3 install --break-system-packages --no-cache-dir prowler || true
  fi
fi

# =============================================================================
# 16/17  Linux endpoint telemetry (Sysmon for Linux)
# =============================================================================
# Microsoft's Sysmon port: process/network/file/DNS eventing to syslog, which
# Wazuh / Elastic can ingest. Optional — only adds repo + package; does NOT
# enable the service by default. Start with `systemctl enable --now sysmon`.
echo "==> [16/17] Linux endpoint telemetry (Sysmon for Linux)"
if ! command -v sysmon >/dev/null 2>&1; then
  UBU_REL="$(lsb_release -rs 2>/dev/null || echo 24.04)"
  # The Microsoft Linux package repo: works for 22.04 and 24.04. Add only once.
  if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
    TMP=$(mktemp -d)
    if curl -fsSL -o "$TMP/ms.deb" \
        "https://packages.microsoft.com/config/ubuntu/${UBU_REL}/packages-microsoft-prod.deb" 2>/dev/null \
        || curl -fsSL -o "$TMP/ms.deb" \
           "https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb"; then
      dpkg -i "$TMP/ms.deb" >/dev/null 2>&1 || true
      apt-get update -y >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP"
  fi
  apt-get install -y sysmonforlinux 2>/dev/null || \
    echo "    sysmonforlinux: apt package unavailable on this release, skipping"
fi

# =============================================================================
# 17/17  GUI tools — Brim / Zui (zeek/suricata log pivoting)
# =============================================================================
# Zui is the modern successor to Brim: desktop Electron app for exploring
# pcap + zeek + suricata logs with a SQL-like query language. GUI-only, so we
# only fetch it when a desktop environment is present.
if [ "$HAS_DESKTOP" = "yes" ]; then
  echo "==> [17/17] Brim/Zui (pcap + zeek log explorer)"
  if ! command -v zui >/dev/null 2>&1 && ! dpkg -s zui >/dev/null 2>&1; then
    ZUI_VER="$(curl -fsSL https://api.github.com/repos/brimdata/zui/releases/latest | jq -r .tag_name | sed 's/^v//')"
    if [ -n "$ZUI_VER" ] && [ "$ZUI_VER" != "null" ]; then
      TMP=$(mktemp -d)
      # Upstream asset name as of Zui 1.18.0 is `zui_${VER}_amd64.deb`.
      # Try that first, fall back to the older capitalised pattern.
      if curl -fsSL --connect-timeout 15 -o "$TMP/zui.deb" \
           "https://github.com/brimdata/zui/releases/download/v${ZUI_VER}/zui_${ZUI_VER}_amd64.deb" \
         || curl -fsSL --connect-timeout 15 -o "$TMP/zui.deb" \
           "https://github.com/brimdata/zui/releases/download/v${ZUI_VER}/Zui-${ZUI_VER}-linux.deb"; then
        apt-get install -y "$TMP/zui.deb" 2>/dev/null \
          || dpkg -i "$TMP/zui.deb" 2>/dev/null \
          || true
        apt-get install -f -y 2>/dev/null || true
      fi
      rm -rf "$TMP"
    fi
  fi
  command -v zui >/dev/null 2>&1 && echo "    zui installed" || \
    echo "    zui: skipped (download failed or not supported on this release)"
else
  echo "==> [17/17] Brim/Zui: skipped (no desktop)"
fi

# =============================================================================
# Summary
# =============================================================================
echo
echo "==> Done. Installed:"
for cmd in \
  nuclei trivy vol volshell log2timeline psort sigma yara \
  wireshark tshark tcpdump tcpreplay ngrep termshark mitmproxy \
  nmap masscan \
  fls mmls icat ewfinfo testdisk foremost scalpel bulk_extractor dc3dd \
  exiftool hashdeep ssdeep hexedit \
  chainsaw hayabusa zircolite regripper evtx_dump \
  binwalk radare2 upx olevba pdfid capa floss clamscan \
  iocextract hashid dnstwist hindsight \
  networkminer autopsy \
  stratus nxc prowler sysmon zui \
  cyberblue-rules atomic-list maltrail-sensor maltrail-server
do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  %-18s %s\n" "$cmd" "$(command -v "$cmd")"
  fi
done

cat <<'EOF'

Quick reference:
  # Network forensics
  wireshark foo.pcap                               # GUI (desktop only)
  zui                                              # GUI pcap + zeek log explorer (desktop only)
  tshark -r foo.pcap -Y http                       # CLI pcap filter
  termshark -r foo.pcap                            # TUI pcap viewer (great over SSH)
  mitmproxy                                        # intercepting proxy (TUI)
  networkminer                                     # pcap host/file/credential extraction
  nmap -sV -A target.example                       # host + service discovery
  masscan 10.0.0.0/24 -p80,443 --rate=1000         # wide-range port sweep

  # Disk forensics
  mmls disk.img                                    # partition layout
  fls -r -o 2048 disk.img                          # recursive file listing
  bulk_extractor -o out/ disk.img                  # IOC/PII extraction

  # Windows triage
  chainsaw hunt evtx/ --sigma sigma/rules/         # Sigma-on-EVTX triage
  hayabusa csv-timeline -d evtx/ -o timeline.csv   # Windows event threat hunt
  zircolite --evtx evtx/ --ruleset rules_medium_generic.json

  # Malware / files
  olevba sample.docm                               # office macro analysis
  pdfid suspicious.pdf && pdf-parser suspicious.pdf
  capa sample.exe                                  # Mandiant capability detection
  floss sample.exe                                 # FLARE obfuscated strings

  # IOC utils
  iocextract < email.eml                           # pull IOCs out of text
  hashid abc123...                                 # what hash type is this?
  dnstwist --registered example.com                # find squatted lookalikes
  hindsight -i Default -f json -o out              # Chrome/Chromium triage

  # Detection rule packs (corpora, not binaries)
  cyberblue-rules                                  # list installed rule paths
  chainsaw hunt evtx/ --sigma /opt/sigma-rules/rules/windows/
  yara -r /opt/yara-rules/yara/ ./samples/

  # Adversary simulation & validation
  atomic-list T1059                                # show Atomic Red Team test
  stratus list aws                                 # list cloud attack scenarios
  nxc smb 10.0.0.0/24 -u admin -p 'P@ss'           # NetExec (AD / SMB / WinRM)

  # Beaconing / traffic baselines
  sudo maltrail-sensor                             # Maltrail sensor (needs root)
  maltrail-server &                                # UI on http://127.0.0.1:8338

  # Cloud posture
  prowler aws                                      # scan the current AWS account
EOF

# =============================================================================
# Desktop UX layer (optional — only runs when a GUI/DE is detected).
# Installs the welcome dashboard, XFCE application menu, cyberblue CLI,
# and a Firefox homepage. See tools/native/desktop/install-desktop.sh.
# =============================================================================

_has_desktop() {
  for pkg in xubuntu-desktop xfce4-session ubuntu-desktop gnome-shell kde-plasma-desktop lxqt-session tasksel-desktop; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then return 0; fi
  done
  # also catch hand-installed X sessions
  [[ -d /usr/share/xsessions ]] && find /usr/share/xsessions -maxdepth 1 -name '*.desktop' -print -quit 2>/dev/null | grep -q . && return 0
  return 1
}

SCRIPT_DIR_NATIVE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_INSTALLER="$SCRIPT_DIR_NATIVE/desktop/install-desktop.sh"

if _has_desktop && [[ -f "$DESKTOP_INSTALLER" ]]; then
  echo
  echo "==> Desktop environment detected → installing welcome dashboard + XFCE menu"
  bash "$DESKTOP_INSTALLER" || echo "!! desktop layer install failed (continuing)"
elif [[ -f "$DESKTOP_INSTALLER" ]]; then
  echo
  echo "==> No desktop environment detected → skipping welcome dashboard / XFCE menu."
  echo "    (Re-run with a desktop installed to enable: sudo bash $DESKTOP_INSTALLER)"
fi
