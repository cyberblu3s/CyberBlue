# 🚀 CyberBlueSOC Quick Reference Guide

# 🚨 **LAB ENVIRONMENT ONLY** 🚨
**⚠️ For educational and testing purposes only - NOT for production use ⚠️**

**Current System Status**: ✅ **Production Ready with 30+ Containers**

---

## 🔑 **Access Information**

### **Primary Portal (HTTPS)**
- **URL**: `https://YOUR_IP:5443`
- **Login**: `admin` / `cyberblue123`
- **Features**: Secure authentication, SSL encryption, real-time monitoring

### **Service Access Matrix**

| Tool | URL | Credentials | Status | Purpose |
|------|-----|-------------|--------|---------|
| **CyberBlue Portal** | `https://YOUR_IP:5443` | admin/cyberblue123 | ✅ HTTPS Auth | Central Management |
| **Velociraptor** | `https://YOUR_IP:7000` | admin/cyberblue | ✅ HTTPS | Endpoint Forensics |
| **Wazuh** | `https://YOUR_IP:7001` | admin/SecretPassword | ✅ HTTPS | SIEM Dashboard |
| **Shuffle** | `https://YOUR_IP:7002` | admin/password | ✅ HTTPS | Security Automation |
| **MISP** | `https://YOUR_IP:7003` | admin@admin.test/admin | ✅ HTTPS | Threat Intelligence |
| **CyberChef** | `http://YOUR_IP:7004` | No Auth | ✅ HTTP | Data Analysis |
| **TheHive** | `http://YOUR_IP:7005` | admin@thehive.local/secret | ✅ HTTP | Case Management |
| **Cortex** | `http://YOUR_IP:7006` | admin/cyberblue123 | ✅ HTTP | Observable Analysis |
| **FleetDM** | `http://YOUR_IP:7007` | Setup Required | ✅ HTTP (amd64 only) | Endpoint Management |
| **Arkime** | `http://YOUR_IP:7008` | admin/admin | ✅ HTTP + Data | Network Analysis |
| **Caldera** | `http://YOUR_IP:7009` | red:cyberblue, blue:cyberblue | ✅ HTTP | Adversary Emulation |
| **EveBox** | `http://YOUR_IP:7015` | No Auth | ✅ HTTP + Events | Suricata Events |
| **Wireshark** | `http://YOUR_IP:7011` | admin/cyberblue | ⚠️ GUI | Protocol Analysis |
| **MITRE Navigator** | `http://YOUR_IP:7013` | No Auth | ✅ HTTP | ATT&CK Visualization |
| **Portainer** | `https://YOUR_IP:9443` | admin/cyberblue123 | ✅ HTTPS | Container Management |

---

## 🔍 **YARA & Sigma - Threat Hunting**

### **YARA Malware Detection**
```bash
# Scan file for malware
yara /opt/yara-rules/malware_index.yar /path/to/file

# Recursive directory scan
yara -r /opt/yara-rules/index.yar /path/to/directory

# Webshell detection
yara /opt/yara-rules/webshells_index.yar /var/www/html/

# Check YARA version and rules
yara --version
ls /opt/yara-rules/
```

### **Sigma Rule Conversion**
```bash
# Convert Sigma rule to OpenSearch (Wazuh)
sigma convert -t opensearch_lucene --without-pipeline rule.yml

# List available targets
sigma list targets

# Validate Sigma rules
sigma check /opt/sigma-rules/rules/

# Count available rules
find /opt/sigma-rules/rules -name "*.yml" | wc -l

# Update rules manually
cd /opt/yara-rules && git pull
cd /opt/sigma-rules && git pull

# Check auto-update schedule
crontab -l | grep -E "yara|sigma"

# View update logs
tail -f /var/log/yara-update.log
tail -f /var/log/sigma-update.log
```

**Installed Rules:**
- YARA: 523+ malware detection rules
- Sigma: 3,047+ SIEM detection rules
- Auto-Update: ✅ Every Sunday at 2:00 AM (automated)

---

## 🔧 **Common Commands**

### **Container Management**
```bash
# Check all containers
sudo docker ps

# Restart all services
sudo docker-compose restart

# Restart specific service
sudo docker-compose restart [service-name]

# View logs
sudo docker logs [container-name]

# Check resource usage
sudo docker stats
```

### **Portal Management**
```bash
# Restart secure portal
sudo docker-compose restart portal

# Rebuild portal (after changes)
sudo docker-compose build --no-cache portal
sudo docker-compose up -d portal
```

### **Enhanced Arkime Operations**
```bash
# Quick Arkime setup with live capture
./fix-arkime.sh --live                    # 1-minute capture (default)
./fix-arkime.sh --live-30s                # 30-second quick test
./fix-arkime.sh --live-5min               # 5-minute investigation

# Custom duration captures
./fix-arkime.sh -t 2min                   # 2-minute capture
./fix-arkime.sh -t 45s                    # 45-second capture

# Force database reinitialization
./fix-arkime.sh --force --live

# Generate PCAP files for analysis (same as fix-arkime.sh)
./generate-pcap-for-arkime.sh --live      # Default 1-minute
./generate-pcap-for-arkime.sh --live-5min # 5-minute capture
./generate-pcap-for-arkime.sh -t 30s      # 30-second capture
```

# Check portal logs
sudo docker logs cyber-blue-portal

# Test HTTPS access
curl -k https://localhost:5443/login
```

### **Arkime Operations**
```bash
# Reinitialize with fresh data
./scripts/initialize-arkime.sh --capture-live

# Check PCAP files
ls -la ./arkime/pcaps/

# Process new PCAP files
sudo docker exec arkime /opt/arkime/bin/capture -c /opt/arkime/etc/config.ini -r /data/pcap/your_file.pcap

# Check database status
curl http://localhost:9200/_cat/indices/arkime*
```

### **Suricata & EveBox**
```bash
# Update network interface dynamically
./update-network-interface.sh --restart-suricata

# Check current interface
ip route | grep default

# Monitor live events
tail -f ./suricata/logs/eve.json

# Check event count
wc -l ./suricata/logs/eve.json
```
---

## 🚨 **Emergency Procedures**


### **Individual Service Recovery**
```bash
# Portal issues
sudo docker-compose stop portal
sudo docker-compose build --no-cache portal
sudo docker-compose up -d portal

# Arkime issues
./scripts/initialize-arkime.sh --force --capture-live

# Suricata issues
./update-network-interface.sh --restart-suricata

# Caldera issues
./install_caldera.sh
```

### **Network Issues**
```bash
# Check interface
ip route | grep default

# Update interface detection
./update-network-interface.sh

# Restart network-dependent services
sudo docker-compose restart suricata evebox arkime
```

---

## 📊 **System Health Checks**

### **Quick Health Verification**
```bash
# Container count (should be 30+)
sudo docker ps | wc -l

# Portal HTTPS test
curl -k -s -o /dev/null -w '%{http_code}' https://localhost:5443/login

# Arkime data check
ls ./arkime/pcaps/*.pcap | wc -l

# Suricata events check
wc -l ./suricata/logs/eve.json

# All services test
for port in 5443 7000 7001 7002 7003 7004 7005 7006 7007 7008 7009 7010 7013 7014 7015 9443; do
  nc -z localhost $port && echo "Port $port: ✅" || echo "Port $port: ❌"
done
```

### **Performance Monitoring**
```bash
# Resource usage
sudo docker stats --no-stream

# Disk usage
df -h

# Memory usage
free -h

# Network interfaces
ip addr show
```

---

## 🎯 **Key Features Status**

- ✅ **HTTPS Portal**: Direct access on port 5443 (authentication removed)
- ✅ **29 Containers**: All security tools operational
- ✅ **Swap Space**: 8GB configured (prevents system hanging/crashes)
- ✅ **YARA**: 523+ malware detection rules installed
- ✅ **Sigma**: 3,047+ universal SIEM detection rules
- ✅ **Hunting Dashboard**: Web-based YARA/Sigma management
- ✅ **Arkime Data**: Sample network traffic ready for analysis
- ✅ **Suricata Events**: 50K+ security events captured
- ✅ **Dynamic Config**: Auto-detects network interfaces
- ✅ **Backup System**: Complete state preservation
- ✅ **SSL Encryption**: Automatic certificate generation

---
