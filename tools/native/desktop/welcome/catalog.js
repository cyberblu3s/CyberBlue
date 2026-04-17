/* catalog.js — the single source of truth for the welcome dashboard.
 *
 * WEB_TOOLS entries are rendered as cards in the top section. Each has a
 * category that drives the filter bar. The `container` key is matched against
 * window.STATUS.containers (written by cbsoc-status-refresh).
 *
 * NATIVE_GROUPS are rendered below. Groups flagged `gui: true` render as
 * cards (click = launch the GUI). Other groups render as chips (click = open
 * a terminal running `<bin> --help`).
 *
 * Keep this file in sync with:
 *   - CyberBlue/portal/templates/index.html  (CYBERBLUE_TOOLS)
 *   - CyberBlue/tools/native/install.sh      (the 44-tool native toolkit)
 */

window.CATALOG = {
  // Order = filter-bar order. "All" is prepended in app.js.
  categories: [
    { id: 'siem',     label: 'SIEM',           ico: '🛡️' },
    { id: 'dfir',     label: 'DFIR',           ico: '🔍' },
    { id: 'cti',      label: 'Threat Intel',   ico: '🧠' },
    { id: 'soar',     label: 'SOAR',           ico: '🤖' },
    { id: 'ids',      label: 'IDS / Network',  ico: '📡' },
    { id: 'redteam',  label: 'Adversary Sim',  ico: '♟️' },
    { id: 'mgmt',     label: 'Endpoint Mgmt',  ico: '💻' },
    { id: 'utility',  label: 'Utility',        ico: '🧰' },
    { id: 'ops',      label: 'Platform Ops',   ico: '⚙️' },
  ],

  web: [
    // --- SIEM ---
    { name: 'Wazuh',           cat: 'siem',    desc: 'Open-source SIEM + HIDS + FIM + vulnerability detection.',
      url: 'https://{{IP}}:7001', container: 'wazuh-dashboard', icon: '🛡️', color: '#10b981',
      creds: { user: 'admin', pass: 'SecretPassword' } },

    // --- DFIR ---
    { name: 'Velociraptor',    cat: 'dfir',    desc: 'Endpoint hunting, live response, artifact collection.',
      url: 'https://{{IP}}:7000', container: 'velociraptor', icon: '🔎', color: '#3b82f6',
      creds: { user: 'admin', pass: 'cyberblue' } },

    // --- Threat Intel ---
    { name: 'MISP',            cat: 'cti',     desc: 'Threat-intel sharing platform: indicators, events, galaxies.',
      url: 'https://{{IP}}:7003', container: 'misp-core', icon: '🧠', color: '#8b5cf6',
      creds: { user: 'admin@admin.test', pass: 'admin' } },
    { name: 'MITRE Navigator', cat: 'cti',     desc: 'Interactive ATT&CK matrix for coverage mapping.',
      url: 'http://{{IP}}:7013', container: 'mitre-navigator', icon: '🗺️', color: '#6366f1',
      creds: { note: 'no authentication' } },

    // --- SOAR ---
    { name: 'TheHive',         cat: 'soar',    desc: 'Collaborative case mgmt for incident responders.',
      url: 'http://{{IP}}:7005', container: 'thehive', icon: '🐝', color: '#ef4444',
      creds: { user: 'admin@thehive.local', pass: 'secret' } },
    { name: 'Cortex',           cat: 'soar',    desc: 'Observable analysis & active response engine.',
      url: 'http://{{IP}}:7006', container: 'cortex', icon: '🤖', color: '#06b6d4',
      creds: { user: 'admin', pass: 'admin' } },
    { name: 'Shuffle',         cat: 'soar',    desc: 'Workflow automation for the SOC — drag-and-drop SOAR.',
      url: 'http://{{IP}}:3001', container: 'shuffle-frontend', icon: '🔀', color: '#f97316',
      creds: { note: 'create admin on first visit' } },

    // --- IDS / Network ---
    { name: 'Arkime',          cat: 'ids',     desc: 'Full-packet-capture search and session browser.',
      url: 'http://{{IP}}:7008', container: 'arkime', icon: '🌐', color: '#14b8a6',
      creds: { user: 'admin', pass: 'admin' } },
    { name: 'Evebox',          cat: 'ids',     desc: 'Suricata alert triage UI — powered by EVE JSON.',
      url: 'http://{{IP}}:7015', container: 'evebox', icon: '👁️', color: '#ec4899',
      creds: { note: 'no authentication' } },

    // --- Adversary Sim / Red-team ---
    { name: 'Caldera',         cat: 'redteam', desc: 'MITRE ATT&CK adversary emulation platform.',
      url: 'http://{{IP}}:7009', container: 'caldera', icon: '♜', color: '#dc2626',
      creds: { user: 'admin', pass: 'admin' } },

    // --- Endpoint Mgmt ---
    { name: 'FleetDM',         cat: 'mgmt',    desc: 'Osquery fleet manager — query every endpoint at once.',
      url: 'http://{{IP}}:7007', container: 'fleet-server', icon: '💻', color: '#8b5cf6',
      creds: { user: 'admin', pass: 'admin123' } },

    // --- Utility / Hunting ---
    { name: 'CyberChef',       cat: 'utility', desc: 'The cyber Swiss-army knife — encode, decode, regex, hash.',
      url: 'http://{{IP}}:7004', container: 'cyberchef', icon: '🔪', color: '#f59e0b',
      creds: { note: 'no authentication' } },

    // --- Platform Ops ---
    { name: 'CyberBlue Portal', cat: 'ops',    desc: 'The legacy tile portal (PyFlask, original UI).',
      url: 'https://{{IP}}:5443', container: 'cyber-blue-portal', icon: '🎛️', color: '#3182ce',
      creds: { note: 'no authentication' } },
    { name: 'Portainer',       cat: 'ops',     desc: 'Container management UI — start/stop/inspect everything.',
      url: 'https://{{IP}}:9443', container: 'portainer', icon: '🐳', color: '#0ea5e9',
      creds: { note: 'create admin on first visit' } },
    { name: 'Grafana',         cat: 'ops',     desc: 'Dashboards for logs, metrics, Zeek & honeypots.',
      url: 'http://{{IP}}:3000', container: 'grafana', icon: '📊', color: '#f97316',
      creds: { user: 'admin', pass: 'cyberblue' } },
    { name: 'CrowdSec LAPI',   cat: 'ops',     desc: 'Collaborative IDS/IPS — community-curated blocklists.',
      url: 'http://{{IP}}:6060/metrics', container: 'crowdsec', icon: '🛡️', color: '#64748b',
      creds: { note: 'metrics-only, no auth' } },
  ],

  nativeGroups: [
    { id: 'network',   label: 'Network Forensics',       ico: '📡', gui: true,  tools: [
      { name: 'Wireshark',      bin: 'wireshark',        gui: true, desc: 'Packet-capture GUI.' },
      { name: 'Zui',            bin: 'zui',              gui: true, desc: 'Brim successor — pivot pcap + zeek + suricata logs.' },
      { name: 'NetworkMiner',   bin: 'networkminer',     gui: true, desc: 'PCAP parser — extracts files, creds, sessions.' },
      { name: 'tshark',         bin: 'tshark',           desc: 'CLI Wireshark. Scripts + tcpdump replacement.' },
      { name: 'termshark',      bin: 'termshark',        desc: 'Terminal UI for Wireshark.' },
      { name: 'tcpdump',        bin: 'tcpdump',          desc: 'The classic sniffer.' },
      { name: 'ngrep',          bin: 'ngrep',            desc: 'grep for network traffic.' },
      { name: 'tcpreplay',      bin: 'tcpreplay',        desc: 'Replay a pcap on a live interface.' },
      { name: 'mitmproxy',      bin: 'mitmproxy',        desc: 'Intercepting HTTP(S) proxy.' },
      { name: 'nmap',           bin: 'nmap',             desc: 'Host / service / OS / script discovery.' },
      { name: 'masscan',        bin: 'masscan',          desc: 'Internet-scale port scanner (rate-limited).' },
    ]},
    { id: 'disk',      label: 'Disk Forensics',          ico: '💽', gui: true, tools: [
      { name: 'Autopsy',        bin: 'autopsy',          gui: true, desc: 'Graphical digital-forensics platform.' },
      { name: 'fls',            bin: 'fls',              desc: 'The Sleuth Kit — list files in an image.' },
      { name: 'mmls',           bin: 'mmls',             desc: 'TSK — list partitions in an image.' },
      { name: 'icat',           bin: 'icat',             desc: 'TSK — extract file by inode.' },
      { name: 'ewfinfo',        bin: 'ewfinfo',          desc: 'libewf — metadata for E01 images.' },
      { name: 'testdisk',       bin: 'testdisk',         desc: 'Partition recovery.' },
      { name: 'foremost',       bin: 'foremost',         desc: 'File carving by signatures.' },
      { name: 'scalpel',        bin: 'scalpel',          desc: 'Fast, configurable file carver.' },
      { name: 'bulk_extractor', bin: 'bulk_extractor',   desc: 'Scans any stream for features (emails, IPs, URLs).' },
      { name: 'binwalk',        bin: 'binwalk',          desc: 'Firmware / embedded-filesystem analysis.' },
      { name: 'dc3dd',          bin: 'dc3dd',            desc: 'Forensic dd — hashing, logging, error handling.' },
    ]},
    { id: 'memory',    label: 'Memory Forensics',        ico: '🧠', tools: [
      { name: 'vol',            bin: 'vol',              desc: 'Volatility 3 — memory image analysis.' },
      { name: 'volshell',       bin: 'volshell',         desc: 'Interactive Python shell against a memory image.' },
    ]},
    { id: 'timeline',  label: 'Timeline / Super-Timeline', ico: '⏱️', tools: [
      { name: 'log2timeline',   bin: 'log2timeline',     desc: 'Plaso — build a super-timeline (Docker wrapper).' },
      { name: 'psort',          bin: 'psort',            desc: 'Plaso — filter & sort a super-timeline.' },
    ]},
    { id: 'windows',   label: 'Windows Artifact Triage', ico: '🪟', tools: [
      { name: 'chainsaw',       bin: 'chainsaw',         desc: 'Hunt through Windows EVTX with Sigma rules.' },
      { name: 'hayabusa',       bin: 'hayabusa',         desc: 'Fast threat-hunting timeline on Windows logs.' },
      { name: 'zircolite',      bin: 'zircolite',        desc: 'Sigma-based detection on EVTX / auditd.' },
      { name: 'regripper',      bin: 'regripper',        desc: 'Windows registry artefact extraction.' },
      { name: 'evtx_dump',      bin: 'evtx_dump',        desc: 'Dump EVTX records to JSON.' },
    ]},
    { id: 'detect',    label: 'Detection Engineering',   ico: '🧪', tools: [
      { name: 'sigma',          bin: 'sigma',            desc: 'Sigma CLI — convert Sigma rules to Splunk / ES / etc.' },
      { name: 'yara',           bin: 'yara',             desc: 'Classify and identify malware samples by pattern.' },
      { name: 'nuclei',         bin: 'nuclei',           desc: 'Template-driven vulnerability & misconfig scanner.' },
      { name: 'trivy',          bin: 'trivy',            desc: 'CVE / IaC / secret scanner (filesystem, images, repos).' },
      { name: 'Sigma rules',    bin: 'cyberblue-rules',  desc: 'SigmaHQ rule pack (/opt/sigma-rules) — 3000+ rules.' },
      { name: 'YARA rules',     bin: 'cyberblue-rules',  desc: 'Neo23x0 signature-base (/opt/yara-rules).' },
    ]},
    { id: 'advsim',    label: 'Adversary Simulation',    ico: '♟️', tools: [
      { name: 'Atomic Red Team',bin: 'atomic-list',      desc: 'Invoke-AtomicRedTeam tests keyed to MITRE ATT&CK.' },
      { name: 'Stratus Red Team', bin: 'stratus',        desc: 'Cloud-native attack emulation (AWS/Azure/K8s).' },
      { name: 'NetExec',        bin: 'nxc',              desc: 'Successor to CrackMapExec — AD / SMB / WinRM / LDAP.' },
    ]},
    { id: 'beacon',    label: 'Beaconing / Traffic',     ico: '📶', tools: [
      { name: 'Maltrail sensor',bin: 'maltrail-sensor',  desc: 'Known-bad traffic detector — needs root for sniffing.' },
      { name: 'Maltrail UI',    bin: 'maltrail-server',  desc: 'Maltrail reporting server (defaults to :8338).' },
    ]},
    { id: 'cloud',     label: 'Cloud Security',          ico: '☁️', tools: [
      { name: 'Prowler',        bin: 'prowler',          desc: 'AWS/Azure/GCP/K8s CSPM scanner (CIS/NIST/etc.).' },
    ]},
    { id: 'malware',   label: 'Malware / File Triage',   ico: '☣️', tools: [
      { name: 'radare2',        bin: 'r2',               desc: 'Reverse-engineering framework (r2 CLI).' },
      { name: 'upx',            bin: 'upx',              desc: 'Unpack UPX-compressed binaries.' },
      { name: 'olevba',         bin: 'olevba',           desc: 'Extract VBA macros from Office documents.' },
      { name: 'pdfid',          bin: 'pdfid',            desc: 'Didier Stevens — triage PDF objects.' },
      { name: 'pdf-parser',     bin: 'pdf-parser',       desc: 'Didier Stevens — deep-dive PDF structure.' },
      { name: 'capa',           bin: 'capa',             desc: 'FLARE — identify capabilities in an executable.' },
      { name: 'floss',          bin: 'floss',            desc: 'FLARE — deobfuscate strings in malware.' },
      { name: 'clamscan',       bin: 'clamscan',         desc: 'ClamAV on-demand scanner.' },
    ]},
    { id: 'ioc',       label: 'IOC / Data Utilities',    ico: '🧰', tools: [
      { name: 'iocextract',     bin: 'iocextract',       desc: 'Pull IOCs (IPs, URLs, hashes) from any blob of text.' },
      { name: 'hashid',         bin: 'hashid',           desc: 'Identify hash algorithms.' },
      { name: 'hashdeep',       bin: 'hashdeep',         desc: 'Recursive hashing + audit against baseline.' },
      { name: 'ssdeep',         bin: 'ssdeep',           desc: 'Fuzzy / context-triggered piecewise hashing.' },
      { name: 'exiftool',       bin: 'exiftool',         desc: 'Read/write metadata from ~every file format.' },
      { name: 'hexedit',        bin: 'hexedit',          desc: 'Interactive hex editor.' },
      { name: 'jq',             bin: 'jq',               desc: 'JSON query/transform — parse EVE, MISP, status.' },
      { name: 'ripgrep',        bin: 'rg',               desc: 'Ludicrously fast grep — for logs and artefacts.' },
      { name: 'dnstwist',       bin: 'dnstwist',         desc: 'Find squatting/lookalike domains of your brand.' },
      { name: 'hindsight',      bin: 'hindsight',        desc: 'Chrome/Chromium history + artefact parser.' },
    ]},
  ],
};
