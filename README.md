# 🛡️ CyberBlueSOC Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Version-1.0--beta-orange.svg)](https://github.com/CyberBlue0/CyberBlue/releases)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-2.0+-blue.svg)](https://docs.docker.com/compose/)
[![Website](https://img.shields.io/badge/Website-cyberblue.co-blue.svg)](https://cyberblue.co)
[![For](https://img.shields.io/badge/Purpose-EDUCATION%20ONLY-red.svg)](https://github.com/CyberBlu3s/CyberBlue#-important-security-notice)

# ⚠️ **EDUCATIONAL & TESTING ENVIRONMENT ONLY** ⚠️

> **🎓 Learning & Training Platform** - Deploy 15+ integrated security tools for cybersecurity education and testing

**CyberBlue** is a comprehensive, containerized cybersecurity **LEARNING PLATFORM** that brings together industry-leading open-source tools for **SIEM**, **DFIR**, **CTI**, **SOAR**, and **Network Analysis**. 

> ### 📘 **Get the CyberBlueSOC Installation & User Guide v1.0**
> 
> 🚀 **Want to deploy CyberBlueSOC step-by-step in less than 60 minutes?**  
> Download the **Free 36-Page Installation and User Guide** that walks you through setup and key configurations.
> 👉 **Access it here:** [**cyberblue.co**](https://cyberblue.co)

## 🚨 **IMPORTANT SECURITY NOTICE**

**⚠️ THIS IS A LEARNING/TESTING ENVIRONMENT ONLY ⚠️**

### **🔴 CRITICAL WARNINGS - READ BEFORE INSTALLING:**

- **🔴 NO SECURITY GUARANTEES** - No warranties, not suitable for processing real sensitive data or monitoring production systems
- **🔴 DEFAULT CREDENTIALS** - All tools use well-known default passwords (admin/cyberblue, etc.)
- **🔴 NO AUTHENTICATION** - Portal has authentication removed for ease of lab access
- **🔴 DEVELOPMENT BUILD** - This is beta software for learning purposes

### **✅ APPROPRIATE USE CASES:**
- 🎓 Cybersecurity training courses and certifications
- 🧪 Security tool evaluation and testing
- 🏫 Academic institutions and research labs
- 💻 Home lab environments (isolated from production)
- 📚 SOC analyst skill development
- 🎯 Capture-the-flag (CTF) and training exercises

### **❌ NEVER USE THIS PLATFORM FOR:**
- ❌ Processing any sensitive, confidential, or production data

### **⚖️ Legal Disclaimer:**
This software is provided "AS IS" for educational purposes. No warranty or guarantee of security. Users are solely responsible for ensuring appropriate use in isolated lab environments. Not liable for any damages or security incidents resulting from use or misuse of this platform.

---

## 🎯 About CyberBlue

**CyberBlue** is an open-source, all-in-one cybersecurity training platform that provides hands-on experience with industry-standard security tools. Built specifically for educational purposes, it allows students, security professionals, and enthusiasts to learn SOC operations, threat hunting, incident response, and security automation in a safe, isolated environment.

**🌐 Website-NotUpYet**: [https://cyberblue.co](https://cyberblue.co)  
**📖 Documentation**: Available in this repository  
**🎓 Purpose**: Educational and training use  
**📜 License**: MIT (Open Source)  
**⚠️ Version**: 1.0-beta (Initial Release)

### **What It Does:**

CyberBlue transforms Blue Team cybersecurity tool deployment into a **like one-command solution**. Built with Docker Compose and featuring a beautiful web portal, it provides enterprise-grade security tool access in minutes, not days - perfect for learning and practicing security operations.

### 🌟 Why CyberBlue for Learning?

- **🚀 Instant Lab Deployment**: Complete SOC training environment in about 30 minutes
- **🎓 Education Focused**: Pre-configured with sample data for hands-on learning
- **🎨 Modern Interface**: Beautiful dark-themed portal for easy tool access
- **🔧 Realistic Setup**: Experience real security tools used in production SOCs
- **🤖 Smart Configuration**: Automatic network detection and setup
- **📊 Sample Data Included**: Arkime with network captures, Suricata with 50K+ events
- **🔍 Threat Hunting Ready**: YARA (523 rules) & Sigma (3,047 rules) pre-installed
- **📚 Learning Resources**: Comprehensive documentation and guides
- **🌐 Free & Open Source**: No licensing costs, perfect for students and labs

---

## 🛡️ Security Tools Included

### 📊 **SIEM & Monitoring**
- **[Wazuh](https://wazuh.com/)** - Host-based intrusion detection and log analysis
- **[Suricata](https://suricata.io/)** - Network intrusion detection and prevention
- **[EveBox](https://evebox.org/)** - Suricata event and alert management

### 🕵️ **DFIR & Forensics**
- **[Velociraptor](https://docs.velociraptor.app/)** - Endpoint visibility and digital forensics
- **[Arkime](https://arkime.com/)** - Full packet capture and network analysis
- **[Wireshark](https://www.wireshark.org/)** - Network protocol analyzer

### 🧠 **Threat Intelligence**
- **[MISP](https://www.misp-project.org/)** - Threat intelligence platform
- **[MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)** - Threat modeling and visualization

### ⚡ **SOAR & Automation**
- **[Shuffle](https://shuffler.io/)** - Security orchestration and automation
- **[TheHive](https://thehive-project.org/)** - Incident response platform
- **[Cortex](https://github.com/TheHive-Project/Cortex)** - Observable analysis engine

### 🔧 **Utilities & Management**
- **[CyberChef](https://gchq.github.io/CyberChef/)** - Cyber Swiss Army knife
- **[Portainer](https://www.portainer.io/)** - Container management interface
- **[FleetDM](https://fleetdm.com/)** - Device management and osquery fleet manager
- **[Caldera](https://caldera.mitre.org/)** - Adversary emulation platform

### 🔍 **Threat Hunting & Detection**
- **[YARA](https://virustotal.github.io/yara/)** - Pattern matching for malware detection and classification
  - **Installation**: Direct host install (no container overhead)
  - **Rules**: 523+ curated rules from [Yara-Rules](https://github.com/Yara-Rules/rules)
  - **Location**: `/opt/yara-rules/`
  - **Usage**: `yara -r /opt/yara-rules/malware_index.yar /path/to/file`
  - **Integration**: Works with Velociraptor, TheHive/Cortex, and CLI

- **[Sigma](https://github.com/SigmaHQ/sigma)** - Universal SIEM rule format and converter
  - **Installation**: Sigma CLI installed on host
  - **Rules**: 3,047+ detection rules from [SigmaHQ](https://github.com/SigmaHQ/sigma)
  - **Location**: `/opt/sigma-rules/`
  - **Usage**: Convert rules to Wazuh/OpenSearch/Elasticsearch format
  - **Command**: `sigma convert -t opensearch_lucene --without-pipeline rule.yml`
  - **Integration**: Generate rules for Wazuh, Suricata, and EveBox

---

## ✨ **NEW: Agent Deployment & Threat Intelligence Hub**

**Portal now includes enterprise-grade agent deployment and threat intelligence features:**

### **🔵 Agent Deployment (Agents Tab)**
- **Velociraptor** - DFIR agent deployment (Windows, Linux, macOS)
- **Wazuh** - HIDS agent deployment (Windows, Linux)
- **Caldera** - Red team/adversary emulation deployment
- **Arkime PCAP** - One-click network traffic capture
- **Shuffle** - SOAR integration guide for 12 tools

**Zero-configuration packages** with auto-extracted certificates and secrets!

### **🧠 Threat Intelligence (Intel Tab)**
- **IOC Search** - Instant search across MISP database
- **Auto-populated MISP** - 280K+ indicators from 5 threat feeds
- **Daily auto-updates** - Fresh threat intel every day
- **Recent Events** - Latest threat intelligence
- **Feed Sync** - On-demand feed updates

**Fully automated** - MISP populates automatically during installation!

### ⚡ Quick Update — Force-Refresh MISP Feeds

1) Log in to your MISP web UI as **admin** and set the password (if it’s your first login).  
2) From the repository root, run:

```bash
bash misp/configure-threat-feeds.sh
```
---

## 🚀 Quick Start

### 📋 System Requirements
- **RAM**: 16+ GB recommended
- **Storage**: 150GB+ free disk space
- **OS**: Ubuntu 22.04+ LTS (tested on 22.04.5 & 24.04.2)
- **Architecture**: **amd64** (x86_64, AWS / VMware / VirtualBox / bare metal) and **arm64** (Apple Silicon via UTM, AWS Graviton, Raspberry Pi-class hardware). See [ARM64 Support](docs/ARM64_SUPPORT.md) for the dual-arch matrix and known arm64 exceptions.
- **Network**: Internet connection for downloads

### ⚡ **Simple Installation**

**Complete CyberBlueSOC installation in few commands:**

```bash
# Clone and install CyberBlue SOC
git clone https://github.com/CyberBlu3s/CyberBlue.git
cd CyberBlue
chmod +x cyberblue_install.sh
./cyberblue_install.sh
```

**That's it!** This will:
- ✅ Install all prerequisites (Docker, Docker Compose, system optimizations)
- ✅ Configure 8GB swap space for system stability (prevents hanging/crashes)
- ✅ Deploy all 15+ security tools automatically  
- ✅ Install YARA (523+ malware rules) and Sigma (3,047+ detection rules)
- ✅ Configure networking and SSL certificates
- ✅ Set up portal access (authentication removed for ease of use)
- ✅ Works on AWS, VMware, VirtualBox, UTM (Apple Silicon), and bare metal
- ✅ Complete setup in about 30 minutes

#### Full Platform (Docker stack + native blue-team toolkit + desktop UX)

For a complete Kali-like blue-team workstation experience (SIEM/SOAR + ~50
native CLI/GUI tools + branded XFCE desktop + welcome dashboard), use the
umbrella initializer instead. Assumes OS prerequisites are already
installed (Docker + desktop environment for the desktop layer).

```bash
# After install-prerequisites.sh / setup-prerequisites.sh / ISO first-boot
cd CyberBlue
./cyberblue_init.sh
```

This chains `cyberblue_install.sh` → `tools/native/install.sh` (which
auto-chains `tools/native/desktop/install-desktop.sh` when a desktop
session is detected). Each stage is idempotent and independently
runnable. Works transparently on amd64 and arm64.

### 🌐 **Access Your SOC Lab**

After installation, access your security lab at:
- **🔒 Portal**: `https://YOUR_SERVER_IP:5443` (no authentication required)
- **🛡️ Tools**: Available on ports 7000-7099

### 🛡️ **What Gets Installed**

The installation automatically:
- ✅ Deploys 15+ integrated security tools
- ✅ Configures 8GB swap space (prevents system hanging and OOM crashes)
- ✅ Installs YARA with 523+ malware detection rules
- ✅ Installs Sigma CLI with 3,047+ universal detection rules
- ✅ Configures secure HTTPS portal (direct access, no login required)
- ✅ Sets up network monitoring with Suricata and Arkime
- ✅ Initializes threat intelligence with MISP
- ✅ Configures SIEM with Wazuh and EveBox
- ✅ Sets up incident response with TheHive and Cortex
- ✅ Deploys automation platform with Shuffle
- ✅ Creates SSL certificates and security credentials
- ✅ Optimizes system for container workloads

### 🌐 **Access Your Security Lab**

After installation, access your tools at:

**🔒 Main Portal:**
```
https://YOUR_SERVER_IP:5443
No authentication required - direct access
```

**🛡️ Individual Tools (ports 7000-7099):**
- **Velociraptor**: https://YOUR_SERVER_IP:7000 (admin/cyberblue)
- **Wazuh**: https://YOUR_SERVER_IP:7001 (admin/SecretPassword)
- **Shuffle**: https://YOUR_SERVER_IP:7002 (admin/password)
- **MISP**: https://YOUR_SERVER_IP:7003 (admin@admin.test/admin)
- **CyberChef**: http://YOUR_SERVER_IP:7004 (no auth)
- **TheHive**: http://YOUR_SERVER_IP:7005 (admin@thehive.local/secret)
- **Cortex**: http://YOUR_SERVER_IP:7006 (admin/cyberblue123)
- **FleetDM**: http://YOUR_SERVER_IP:7007 (setup required)
- **Arkime**: http://YOUR_SERVER_IP:7008 (admin/admin)
- **Caldera**: http://YOUR_SERVER_IP:7009 (red:cyberblue, blue:cyberblue)
- **EveBox**: http://YOUR_SERVER_IP:7015 (no auth)
- **Wireshark**: http://YOUR_SERVER_IP:7011 (admin/cyberblue)
- **MITRE Navigator**: http://YOUR_SERVER_IP:7013 (no auth)
- **Portainer**: https://YOUR_SERVER_IP:9443 (admin/cyberblue123)

---

## 📖 Documentation

### 📚 Comprehensive Documentation
- **[⚡ Quick Reference](QUICK_REFERENCE.md)** - Essential commands and access information
- **[🔍 Arkime Setup](ARKIME_SETUP.md)** - Network analysis with sample data
- **[⚙️ Tool Configurations](docs/TOOL_CONFIGURATIONS.md)** - Advanced tool setup and customization
- **[🔌 API Reference](docs/API_REFERENCE.md)** - Portal API documentation
- **[🔧 Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[🧩 ARM64 Support](docs/ARM64_SUPPORT.md)** - Dual-arch matrix, arm64 exceptions, verification commands
- **[🛠️ Native Blue-Team Toolkit](tools/native/README.md)** - CLI/GUI tools installed alongside the container stack

---

## 🎨 CyberBlue Portal Features

The CyberBlue Portal provides a secure, unified interface for managing your security lab:

### 📊 **Enhanced Dashboard**
- Real-time container status monitoring (30+ containers)
- System resource utilization tracking
- Security metrics and trends visualization
- Activity logging and comprehensive changelog
- Container health indicators with status alerts

### 🔧 **Container Management**
- One-click start/stop/restart controls for all services
- Health status indicators with real-time updates
- Resource usage monitoring and alerts
- Log viewing capabilities for troubleshooting
- Automated container monitoring and recovery

### 🛡️ **Security Overview**
- Tool categorization (SIEM, DFIR, CTI, SOAR, Utilities)
- Quick access to all 15+ security tools
- Integration status monitoring across platforms
- Security posture dashboard with threat metrics
- Automated service health checking

### 🔍 **Search & Filter**
- Global tool search functionality
- Category-based filtering (SIEM, DFIR, CTI, etc.)
- Status-based filtering (Running, Stopped, Critical)
- Organized tool layout with descriptions and credentials

---

## 🐳 Architecture

CyberBlue uses a microservices architecture with Docker Compose:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CyberBlue     │    │   SIEM Stack    │    │   DFIR Stack    │
│     Portal      │    │                 │    │                 │
│   (Flask App)   │    │ • Wazuh         │    │ • Velociraptor  │
│                 │    │ • Suricata      │    │ • Arkime        │
│                 │    │ • EveBox        │    │ • Wireshark     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌─────────────────┐    ┌┴─────────────────┐    ┌─────────────────┐
         │   CTI Stack     │    │ Docker Network   │    │  SOAR Stack     │
         │                 │    │  (172.18.0.0/16) │    │                 │
         │ • MISP          │    │                  │    │ • Shuffle       │
         │ • MITRE ATT&CK  │    │                  │    │ • TheHive       │
         │                 │    │                  │    │ • Cortex        │
         └─────────────────┘    └──────────────────┘    └─────────────────┘
```

---


## 📋 System Requirements

### Recommended Requirements
- **CPU**: 8+ cores
- **RAM**: 16GB+
- **Storage**: 100GB+ SSD
- **Network**: Gigabit Ethernet

---

## 🔧 Troubleshooting

### 🆘 **Quick Fixes**

**If installation fails or containers won't start:**
```bash
# Complete system restart (recommended)
./force-start.sh

# Check all containers (should show 30+ running)
sudo docker ps

# View portal logs
sudo docker logs cyber-blue-portal
```

**Portal not accessible:**
```bash
# Test HTTPS access
curl -k https://localhost:5443/health

# Restart portal
sudo docker-compose restart portal
```

**Fleet database issues:**
```bash
# Fix Fleet database
./fix-fleet.sh

# Check Fleet status
sudo docker logs fleet-server
```

**Individual tool issues:**
```bash
# Restart specific service
sudo docker-compose restart [service-name]

# Check service logs
sudo docker logs [container-name]

# Check system resources
sudo docker stats
```

### 🛠️ **Utility Scripts**

- **`./setup-prerequisites.sh`** - Install all system prerequisites
- **`./cyberblue_install.sh`** - Main CyberBlue installation script  
- **`./force-start.sh`** - Emergency restart for all services
- **`./fix-fleet.sh`** - Fix Fleet database issues

---

## 🔍 YARA & Sigma - Threat Hunting Guide

### 📋 **YARA - Malware Detection**

**What is YARA?**  
YARA is the industry-standard tool for identifying and classifying malware based on textual or binary patterns.

**Installation Location:**
- **Binary**: `/usr/bin/yara`
- **Rules**: `/opt/yara-rules/` (523+ rules)
- **Version**: 4.1.3

**Available Rule Categories:**
```bash
/opt/yara-rules/
├── malware/              # Malware family detection (APTs, trojans, ransomware)
├── webshells/            # Web shell detection
├── cve_rules/            # CVE exploit detection
├── packers/              # Packer and crypter detection
├── crypto/               # Cryptographic algorithm detection
├── capabilities/         # Malware capability detection
├── email/                # Email-based threat detection
├── exploit_kits/         # Exploit kit detection
└── mobile_malware/       # Android/iOS malware
```

**Quick Start Examples:**

```bash
# Scan a single file with all malware rules
yara /opt/yara-rules/malware_index.yar /path/to/suspicious_file

# Recursive scan of directory
yara -r /opt/yara-rules/index.yar /path/to/directory

# Scan with specific category (webshells)
yara /opt/yara-rules/webshells_index.yar /var/www/html/

# Fast scan with timeout
yara -f -w -d timeout=60 /opt/yara-rules/malware_index.yar /path/to/files

# Scan memory dumps
sudo yara /opt/yara-rules/malware_index.yar /proc/*/mem
```

**Integration Examples:**

```bash
# Integration with Velociraptor
# Create a hunt artifact that runs YARA against collected files

# Integration with TheHive/Cortex
# Use YARA as a Cortex analyzer for file observables

# Automated scanning script
#!/bin/bash
for file in /path/to/suspicious/*; do
    yara -r /opt/yara-rules/malware_index.yar "$file" >> yara_scan_results.log
done
```

**Common YARA Rule Indexes:**
- `index.yar` - All rules combined
- `malware_index.yar` - All malware rules
- `webshells_index.yar` - All webshell rules  
- `cve_rules_index.yar` - All CVE exploit rules
- `crypto_index.yar` - Crypto-related rules

---

### 📊 **Sigma - Universal Detection Rules**

**What is Sigma?**  
Sigma is a generic signature format for SIEM systems, allowing you to write detection rules once and convert them to any SIEM platform.

**Installation Location:**
- **CLI**: `/usr/local/bin/sigma`
- **Rules**: `/opt/sigma-rules/` (3,047+ rules)
- **Backends**: OpenSearch, Elasticsearch, Lucene

**Available Rule Categories:**
```bash
/opt/sigma-rules/
├── rules/                          # Main detection rules
│   ├── windows/                    # Windows event log rules
│   ├── linux/                      # Linux system rules
│   ├── cloud/                      # Cloud platform rules (AWS, Azure, GCP)
│   ├── network/                    # Network traffic rules
│   ├── application/                # Application-specific rules
│   └── proxy/                      # Proxy and web traffic rules
├── rules-threat-hunting/           # Threat hunting focused rules
├── rules-emerging-threats/         # Latest threat intel rules
└── rules-compliance/               # Compliance and audit rules
```

**Quick Start Examples:**

```bash
# List available conversion targets
sigma list targets

# Convert single rule to OpenSearch (for Wazuh)
sigma convert -t opensearch_lucene --without-pipeline \
    /opt/sigma-rules/rules/linux/process_creation/proc_creation_lnx_susp_nohup.yml

# Convert Windows process creation rules to OpenSearch
sigma convert -t opensearch_lucene --without-pipeline \
    /opt/sigma-rules/rules/windows/process_creation/*.yml \
    -o /tmp/wazuh-rules.json

# Convert all rules in a directory
sigma convert -t lucene --without-pipeline \
    /opt/sigma-rules/rules/linux/ \
    -o /tmp/linux-detection-rules.txt

# Validate rules before conversion
sigma check /opt/sigma-rules/rules/windows/process_creation/

# Analyze rule coverage
sigma analyze /opt/sigma-rules/rules/
```

**Integration with Wazuh:**

```bash
# Convert Sigma rules to OpenSearch format for Wazuh
sigma convert -t opensearch_lucene --without-pipeline \
    /opt/sigma-rules/rules/windows/ \
    -o /tmp/wazuh-windows-rules.json

# Apply rules to Wazuh (manual import via Dashboard > Management > Rules)
# Or programmatically via Wazuh API
```

**Integration with Suricata:**

```bash
# While Sigma doesn't directly convert to Suricata format,
# you can use the network rules as reference for creating Suricata rules
sigma list /opt/sigma-rules/rules/network/
```

**Common Use Cases:**

```bash
# 1. Detect PowerShell abuse
sigma convert -t opensearch_lucene --without-pipeline \
    /opt/sigma-rules/rules/windows/powershell/ -o powershell-detections.json

# 2. Detect lateral movement
sigma convert -t opensearch_lucene --without-pipeline \
    /opt/sigma-rules/rules/windows/builtin/security/win_security_susp_failed_logons.yml

# 3. Detect ransomware indicators
find /opt/sigma-rules/rules -name "*ransom*" -o -name "*crypt*" | \
    xargs sigma convert -t opensearch_lucene --without-pipeline

# 4. Cloud security monitoring (AWS/Azure/GCP)
sigma convert -t opensearch_lucene --without-pipeline \
    /opt/sigma-rules/rules/cloud/ -o cloud-detections.json
```

**Rule Statistics:**
- **Total Sigma Rules**: 3,047+
- **Windows Rules**: 2,500+
- **Linux Rules**: 200+
- **Cloud Rules**: 150+
- **Network Rules**: 100+
- **Application Rules**: 97+

**Best Practices:**

1. **Test rules before deployment**: Use `sigma check` to validate
2. **Start with high-confidence rules**: Focus on emerging-threats category
3. **Tune for your environment**: Adjust thresholds and conditions
4. **Regular updates**: Pull latest rules weekly
5. **Document custom rules**: Keep your own rule repository

**Auto-Update Configuration:**

CyberBlue automatically updates YARA and Sigma rules **every Sunday at 2:00 AM** via cron.

```bash
# View configured auto-update schedule
crontab -l | grep -E "yara|sigma"

# Manual update anytime
cd /opt/yara-rules && git pull
cd /opt/sigma-rules && git pull

# Check update logs
tail -f /var/log/yara-update.log
tail -f /var/log/sigma-update.log

# Disable auto-update (if needed)
crontab -l | grep -v "yara-rules\|sigma-rules" | crontab -
```

**Update Schedule:**
- **YARA Rules**: Every Sunday at 2:00 AM → `/var/log/yara-update.log`
- **Sigma Rules**: Every Sunday at 2:05 AM → `/var/log/sigma-update.log`
- **Automatic**: Configured during installation, no manual setup required

---

## 📊 Monitoring & Metrics

CyberBlue includes built-in monitoring:

- **Container Health**: Real-time status monitoring
- **Resource Usage**: CPU, memory, disk utilization

---

## 🔒 Security Considerations for Lab Environments

**⚠️ Remember: This is a TRAINING platform, not a production security solution!**

- **Network Isolation**: Deploy only in isolated lab networks, never on production
- **Access Control**: Default credentials are intentionally simple for lab use
- **SSL/TLS**: Self-signed certificates included (accept warnings in lab)
- **Firewall**: Keep isolated from production systems
- **Data**: Never process real sensitive data with this platform

---

## 🌐 Learn More

- **🌍 Official Website (Not Up Yet)**: [https://cyberblue.co](https://cyberblue.co)
- **📚 Documentation**: Available in this repository
- **⭐ Star the Project**: Help others discover CyberBlue!

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Educational Use Only** - Not for production security operations.

---

## 🙏 Acknowledgments & Credits

This project stands on the shoulders of giants. We are deeply grateful to the entire open-source security community:

### **🏢 Organizations & Projects:**
- **[Wazuh](https://wazuh.com/)** - For the exceptional open-source SIEM platform
- **[The Hive Project](https://thehive-project.org/)** - For TheHive and Cortex incident response tools
- **[Yara-Rules Community](https://github.com/Yara-Rules/rules)** - For 523+ curated malware detection signatures
- **[SigmaHQ](https://github.com/SigmaHQ/sigma)** & **Florian Roth** - For 3,047+ universal SIEM detection rules
- **[Velociraptor](https://www.velocidex.com/)** - For the powerful DFIR platform
- **[Arkime Project](https://arkime.com/)** - For full packet capture and analysis
- **[MISP Project](https://www.misp-project.org/)** - For threat intelligence sharing
- **[Shuffle](https://shuffler.io/)** - For security automation and orchestration
- **[Suricata](https://suricata.io/)** - For network intrusion detection
- **[EveBox](https://evebox.org/)** - For Suricata event management
- **[FleetDM](https://fleetdm.com/)** - For osquery fleet management
- **[Caldera](https://caldera.mitre.org/)** - For adversary emulation
- **[CyberChef](https://gchq.github.io/CyberChef/)** - For the Swiss Army knife of cyber operations
- **[Portainer](https://www.portainer.io/)** - For container management
- **[GCHQ](https://www.gchq.gov.uk/)** - For CyberChef and inspiring security innovation
- **[MITRE Corporation](https://attack.mitre.org/)** - For the ATT&CK framework that revolutionized threat intelligence
- **[Elastic](https://www.elastic.co/)** - For Elasticsearch and the ELK stack foundation

### **👨‍💻 Individual Contributors:**
- **Florian Roth** ([Neo23x0](https://github.com/Neo23x0)) - Sigma rules, YARA expertise, and tireless security research
- All **YARA rule authors** who share their detection knowledge
- All **Sigma rule contributors** improving detection capabilities daily
- **Docker community** for containerization best practices
- Every **security researcher** who open-sources their work

---

## ⚠️ Final Reminder

**This platform is designed for LEARNING and TRAINING purposes only.**

- ✅ Perfect for: Cybersecurity education, hands-on training, skill development
- ❌ Never use for: real security operations, sensitive data

---

<div align="center">

**⭐ Star this repository if you find it useful for learning!**

**🌐 Visit [cyberblue.co](https://cyberblue.co) for tutorials and guides (Not Up Yet)**

*CyberBlue v1.0-beta - Educational Cybersecurity Training Platform*

</div>
