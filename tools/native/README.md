# Native blue-team toolkit

Some SOC tools are **commands**, not services. Others are **desktop GUI apps** users open on demand. Neither belongs in an always-on container — it just wastes RAM and breaks the "type the command" UX. These live on the host.

## One-line install

```bash
sudo /home/ubuntu/CyberBlue/tools/native/install.sh
```

Idempotent — safe to re-run after `git pull`.
Logs to `/var/log/cyberbluesoc-native-install.log`.

## What gets installed (55+ tools)

### Vulnerability & policy scanning
| Tool | Source | Purpose |
|---|---|---|
| `nuclei` | binary | Signature-based vuln scanner (replaces OpenVAS at our scale) |
| `trivy` | apt | Container image / filesystem / IaC vuln scanner |

### Memory & timeline forensics
| Tool | Source | Purpose |
|---|---|---|
| `vol`, `volshell` | pip | Volatility 3 memory forensics |
| `log2timeline`, `psort` | Docker wrapper | Plaso timeline forensics |

### Detection engineering
| Tool | Source | Purpose |
|---|---|---|
| `sigma` | pip (pysigma-cli) | Convert Sigma rules to OpenSearch/Splunk/etc queries |
| `yara` | apt | Pattern-matching engine |

### Network forensics (replaces the Wireshark container)
| Tool | Source | Purpose |
|---|---|---|
| `wireshark` | apt | The GUI packet analyzer, installed only if a desktop is present |
| `zui` | brimdata .deb | Brim's successor — GUI pivoting over pcap + Zeek + Suricata logs |
| `tshark` | apt | Wireshark's CLI — scriptable pcap filtering |
| `tcpdump` | apt | Classic packet capture |
| `tcpreplay` | apt | Replay pcaps into Suricata/Zeek |
| `ngrep` | apt | grep-on-the-wire |
| `termshark` | apt | TUI pcap viewer — great over SSH |
| `mitmproxy` | apt | TLS intercepting proxy |
| `networkminer` | Mono wrapper | pcap host/file/credential extraction (GUI) |
| `nmap` | apt | Host / service / OS / script discovery |
| `masscan` | apt | Internet-scale port scanner (rate-limited) |

### Disk / dead-box forensics
| Tool | Source | Purpose |
|---|---|---|
| `fls`, `mmls`, `icat` | apt (sleuthkit) | Foundation disk analysis CLIs |
| `ewfinfo` | apt (ewf-tools) | E01 evidence image inspection |
| `afflib-tools` | apt | AFF evidence format |
| `testdisk`, `photorec` | apt | Partition + file recovery |
| `foremost`, `scalpel` | apt | File carving |
| `bulk_extractor` | binary (best-effort) | IOC/PII extraction from disks |
| `exiftool` | apt | Metadata from (almost) anything |
| `hashdeep`, `ssdeep` | apt | Recursive + fuzzy hashing |
| `hexedit` | apt | Terminal hex editor |
| `dc3dd` | apt | Forensic `dd` — hashing, logging, error handling |
| `autopsy` | apt | Sleuth Kit's GUI for disk forensics |

### Windows artifact triage
| Tool | Source | Purpose |
|---|---|---|
| `chainsaw` | binary | Fast EVTX triage with Sigma/built-in rules |
| `hayabusa` | binary | Comprehensive Windows event log threat hunting |
| `zircolite` | git clone | SIGMA engine over EVTX/JSON/auditd |
| `regripper` | apt | Windows registry hive parser |
| `evtx_dump` | pip (evtx) | EVTX → XML |

### Malware / file triage
| Tool | Source | Purpose |
|---|---|---|
| `binwalk` | apt | Firmware / embedded file carving |
| `radare2` | apt | Reverse engineering CLI |
| `upx` | apt | Pack/unpack UPX |
| `olevba`, `oleid`, `rtfobj` | pip (oletools) | Office macro & RTF analysis |
| `pdfid`, `pdf-parser` | Didier Stevens | PDF triage |
| `capa` | pip (flare-capa) | Mandiant capability detection |
| `floss` | pip (flare-floss) | FLARE obfuscated-string extractor |
| `clamscan` | apt | AV scanning on demand (daemon disabled by default) |

### IOC / data utilities
| Tool | Source | Purpose |
|---|---|---|
| `jq`, `ripgrep` | apt | JSON / log slicing |
| `iocextract` | pip | Pull IOCs out of any blob of text |
| `hashid` | pip | Hash-type identification |
| `dnstwist` | pip | Domain-squat / lookalike detection |
| `hindsight` | pip (pyhindsight) | Chrome / Chromium history + artefact parser |
| `exiftool` | apt | (listed above, also IOC pivots) |

### Detection rule packs (corpora, not binaries)
| Pack | Path | Content |
|---|---|---|
| SigmaHQ rules | `/opt/sigma-rules/rules` | 3000+ community-maintained Sigma rules |
| Neo23x0 signature-base | `/opt/yara-rules` | Florian Roth's YARA signature base |
| Browse | `cyberblue-rules` | One-line CLI summary of installed packs |

### Adversary simulation & validation
| Tool | Source | Purpose |
|---|---|---|
| Atomic Red Team | git clone → `/opt/atomic-red-team` | Red Canary's library of ATT&CK-mapped tests |
| `atomic-list` | wrapper | Browse atomics by technique ID (`atomic-list T1059`) |
| `stratus` | Go binary | DataDog's Stratus Red Team — cloud attack emulator |
| `nxc` (NetExec) | git | CrackMapExec successor — AD/SMB/WinRM/LDAP |

### Beaconing / known-bad traffic detection
| Tool | Source | Purpose |
|---|---|---|
| `maltrail-sensor` | git → `/opt/maltrail` | Sniffer that flags traffic to blacklisted IPs / domains |
| `maltrail-server` | git → `/opt/maltrail` | Reporting UI (default `:8338`) |

### Cloud security posture
| Tool | Source | Purpose |
|---|---|---|
| `prowler` | pipx | AWS / Azure / GCP / K8s CSPM scanner (CIS, NIST, SOC2) |

### Linux endpoint telemetry
| Tool | Source | Purpose |
|---|---|---|
| `sysmon` (for Linux) | Microsoft apt repo | Process / network / file / DNS events to syslog (opt-in — `systemctl enable --now sysmon`) |

## Why native, not Docker?

- CLI / on-demand tools have **0 idle RAM**; 35 idle containers would eat gigabytes.
- Users expect `nuclei https://target` and `wireshark foo.pcap` to just work — not `docker run --rm -it`.
- Output files land in the user's CWD naturally; no volume-mount gymnastics.
- GUI apps (Wireshark, Autopsy, NetworkMiner) are a catastrophe in a KasmWeb container vs. a real desktop launcher.
- Matches the Kali Linux model users coming from a "blue Kali" already understand.

## Quick reference

```bash
# Vulnerability scanning
nuclei -u https://target.example.com
trivy image wazuh/wazuh-manager:4.7.5
trivy fs /home/ubuntu

# Network forensics
wireshark foo.pcap                              # desktop GUI
tshark -r foo.pcap -Y http                      # CLI filter
termshark -r foo.pcap                           # TUI viewer over SSH
mitmproxy                                       # TLS intercept
networkminer                                    # pcap host/credential extraction (GUI)

# Disk forensics
mmls disk.img                                   # partition layout
fls -r -o 2048 disk.img                         # recursive file listing
bulk_extractor -o out/ disk.img                 # IOC/PII extraction
autopsy                                         # GUI disk forensics

# Windows triage
chainsaw hunt evtx/ --sigma sigma/rules/
hayabusa csv-timeline -d evtx/ -o timeline.csv
zircolite --evtx evtx/ --ruleset rules_medium_generic.json

# Memory & timeline
vol -f memory.dmp windows.pslist
log2timeline timeline.plaso /path/to/image
psort -o l2tcsv -w timeline.csv timeline.plaso

# Malware / files
olevba sample.docm
pdfid suspicious.pdf && pdf-parser suspicious.pdf
capa sample.exe
floss sample.exe

# IOC utilities
iocextract < email.eml
hashid 'abc123...'
exiftool evidence.jpg
dnstwist --registered example.com
hindsight -i ~/.config/google-chrome/Default -o out

# Detection rule packs
cyberblue-rules                                  # show installed pack paths
chainsaw hunt evtx/ --sigma /opt/sigma-rules/rules/windows/
yara -r /opt/yara-rules/yara/ ./samples/

# Adversary simulation
atomic-list T1059                                # dump an Atomic test
stratus list aws                                 # list cloud attack scenarios
nxc smb 10.0.0.0/24 -u admin -p 'P@ss'           # NetExec sweep

# Beaconing
sudo maltrail-sensor                             # sniffer (needs root)
maltrail-server &                                # UI on :8338

# Cloud posture
prowler aws
```

## Desktop-ISO phase (queued for later)

Heavier GUI apps that make sense on the Ubuntu Desktop ISO but not on the headless lab:

- **Ghidra** — NSA Java RE suite
- **Cutter** — Rizin GUI
- **Burp Suite Community** — web proxy

Everything else in this file — including **Brim/Zui** — already ships on the lab VM.
These will be added to a sibling `install-desktop.sh` during the ISO build phase.

## Updating

Re-run the installer:

```bash
sudo ./tools/native/install.sh
```

For nuclei templates only:

```bash
nuclei -update-templates
```
