# 🔧 CyberBlue Troubleshooting Guide

Comprehensive troubleshooting guide for common issues in CyberBlue deployments.

---

## 🎯 Quick Diagnostics

### System Health Check
```bash
# Run this script to get overall system status
#!/bin/bash
echo "=== CyberBlue System Health Check ==="
echo
echo "1. Docker Status:"
systemctl is-active docker
echo
echo "2. Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"
echo
echo "3. Resource Usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo
echo "4. Disk Usage:"
df -h
echo
echo "5. Network Connectivity:"
for port in 5500 7000 7001 7002 7003; do
  nc -z localhost $port && echo "Port $port: OPEN" || echo "Port $port: CLOSED"
done
```

---

## 🚨 **Common Issues & Solutions**

### 1. **Docker Compose Version Compatibility**

#### Issue: "docker-compose up -d fails with version errors"
**Symptoms:**
- `docker-compose up -d` command fails
- Docker Compose version compatibility errors
- Commands not recognized
- Installation script exits with compose errors

**Diagnosis:**
```bash
# Check Docker Compose version
docker-compose --version
docker compose version

# Check if V2 plugin is installed
docker compose version 2>/dev/null && echo "V2 installed" || echo "V2 missing"
```
**Solutions:**
1. **Install Docker Compose V2 Plugin (Recommended):**
   ```bash
   # Update package list
   sudo apt-get update
   
   # Install Docker Compose V2 plugin
   sudo apt-get install -y docker-compose-plugin
   
   # Verify installation
   docker compose version
   ```

2. **Update Standalone Binary (Alternative):**
   ```bash
   # Download latest Docker Compose binary
   sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   
   # Make executable
   sudo chmod +x /usr/local/bin/docker-compose
   
   # Verify version
   docker-compose --version
   ```
   
**After Installing/Updating:**
   ```bash
   # Retry CyberBlueSOC installation
   ./cyberblue_install.sh
   ```
   
**Note:** Docker Compose V2 uses docker compose (space), V1 uses docker-compose (hyphen). Both can coexist safely.

**Credit:** Thanks to the community [@ljamel](https://github.com/ljamel) for reporting and providing solutions!

### 2. **Container Start Failures**

#### Issue: "Container exits immediately"
**Symptoms:**
- Container shows "Exited (1)" status
- Services not accessible

**Diagnosis:**
```bash
# Check container logs
docker logs [container-name]

# Check resource usage
docker stats --no-stream

# Check available disk space
df -h
```

**Solutions:**
1. **Memory Issues:**
   ```bash
   # Increase virtual memory for Elasticsearch/OpenSearch
   sudo sysctl -w vm.max_map_count=262144
   echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
   ```

2. **Permission Issues:**
   ```bash
   # Fix file permissions
   sudo chown -R $USER:docker ./configs
   sudo chmod -R 755 ./configs
   ```

3. **Port Conflicts:**
   ```bash
   # Check port usage
   netstat -tulpn | grep [PORT_NUMBER]
   
   # Kill conflicting process
   sudo kill -9 [PID]
   ```

### 3. **Portal Access Issues**

#### Issue: "Portal not accessible on port 5500"
**Symptoms:**
- Browser shows "Connection refused"
- Portal container running but not responding

**Diagnosis:**
```bash
# Check portal container
docker logs cyber-blue-portal

# Test local connectivity
curl -f http://localhost:5500

# Check firewall status
sudo ufw status
```

**Solutions:**
1. **Firewall Configuration:**
   ```bash
   # Open required ports
   sudo ufw allow 5500
   sudo ufw allow 7000:7099/tcp
   ```

2. **Container Restart:**
   ```bash
   # Restart portal container
   docker-compose restart portal
   
   # Force recreate if needed
   docker-compose up -d --force-recreate portal
   ```

3. **Check Environment Variables:**
   ```bash
   # Verify .env configuration
   grep -E "HOST_IP|PORTAL_PORT" .env
   ```

### 4. **Wazuh Issues**

#### Issue: "Wazuh dashboard not loading"
**Symptoms:**
- 502 Bad Gateway error
- Dashboard container healthy but interface not accessible

**Diagnosis:**
```bash
# Check all Wazuh containers
docker ps | grep wazuh

# Check indexer health
curl -k https://localhost:9200/_cluster/health

# Check manager API
curl -k https://localhost:55000/
```

**Solutions:**
1. **Wait for Full Startup:**
   ```bash
   # Wazuh components have dependencies
   # Wait 2-3 minutes after starting
   
   # Check startup order
   docker-compose logs wazuh.indexer
   docker-compose logs wazuh.manager
   docker-compose logs wazuh.dashboard
   ```

2. **Certificate Issues:**
   ```bash
   # Regenerate certificates
   docker-compose run --rm generator
   docker-compose restart wazuh.manager wazuh.indexer wazuh.dashboard
   ```

3. **Reset Wazuh Data:**
   ```bash
   # Stop services
   docker-compose stop wazuh.indexer wazuh.dashboard wazuh.manager
   
   # Remove volumes
   docker volume rm cyberblue_wazuh-indexer-data
   
   # Restart
   docker-compose up -d wazuh.indexer wazuh.manager wazuh.dashboard
   ```

### 5. **MISP Configuration Issues**

#### Issue: "MISP showing database connection errors"
**Symptoms:**
- MISP web interface shows database errors
- Container logs show MySQL connection failures

**Diagnosis:**
```bash
# Check MISP containers
docker ps | grep misp

# Test database connectivity
docker exec misp-core php /var/www/MISP/app/Console/cake Admin getSetting "MISP.baseurl"

# Check database logs
docker logs misp-db
```

**Solutions:**
1. **Database Reset:**
   ```bash
   # Stop MISP services
   docker-compose stop misp-core misp-modules
   
   # Reset database
   docker-compose restart db
   
   # Wait for DB startup then restart MISP
   sleep 30
   docker-compose up -d misp-core misp-modules
   ```

2. **Fix Permissions:**
   ```bash
   # Fix file permissions
   sudo chown -R 33:33 ./configs
   sudo chown -R 33:33 ./files
   ```

### 6. **Velociraptor Connection Issues**

#### Issue: "Cannot access Velociraptor GUI"
**Symptoms:**
- HTTPS certificate warnings
- GUI not loading properly

**Solutions:**
1. **Certificate Acceptance:**
   - Accept browser security warnings for self-signed certificates
   - Add certificate exception permanently

2. **Alternative Access:**
   ```bash
   # Access via different browsers
   # Chrome: --ignore-certificate-errors flag
   # Firefox: Accept security exception
   ```

3. **Container Restart:**
   ```bash
   docker-compose restart velociraptor
   ```

### 7. **Suricata Interface Issues**

#### Issue: "Suricata not capturing traffic"
**Symptoms:**
- No alerts in EveBox
- Suricata logs show interface errors

**Diagnosis:**
```bash
# Check network interfaces
ip link show

# Check Suricata configuration
docker exec suricata cat /etc/suricata/suricata.yaml | grep interface

# Check Suricata logs
docker logs suricata
```

**Solutions:**
1. **Interface Configuration:**
   ```bash
   # Update .env with correct interface
   ACTIVE_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
   echo "SURICATA_INT=$ACTIVE_INTERFACE" >> .env
   
   # Restart Suricata
   docker-compose restart suricata
   ```

2. **Permission Issues:**
   ```bash
   # Ensure privileged mode
   # Check docker-compose.yml has:
   # privileged: true
   # cap_add: NET_ADMIN, NET_RAW
   ```

### Docker socket permission denied (`/var/run/docker.sock`)

**Symptom:** `cyberblue status`, `docker ps`, or any compose command
returns `permission denied while trying to connect to the Docker daemon
socket` even though the current user is in the `docker` group.

**Root cause:** On first boot the `docker` daemon can start *before* the
`docker` group is fully propagated to the socket creator's credentials,
leaving `/run/docker.sock` owned by a stray numeric uid (e.g. `1001:1001`)
instead of `root:docker 0660`. Adding the user to the group, relogging,
and even `newgrp docker` will not fix it because the socket itself has
wrong ownership on disk. Observed on fresh Ubuntu Server 24.04 arm64
installs (UTM VM) during Phase 4 smoke tests.

**Diagnose:**
```bash
ls -l /var/run/docker.sock /run/docker.sock
# Expect:  srw-rw---- 1 root docker 0 ...
# Bad:     srw-rw---- 1 <uid> <uid>   (numeric / non-docker group)
id -nG | tr ' ' '\n' | grep -x docker   # must print 'docker'
```

**Fix (safe, no data loss):**
```bash
sudo systemctl stop docker.socket docker.service
sudo rm -f /run/docker.sock /var/run/docker.sock
sudo systemctl start docker.socket docker.service
ls -l /var/run/docker.sock      # should now be root:docker
```
Then re-run `cyberblue status`. If you were in the middle of a
`cyberblue_install.sh` run, re-run it — the script is idempotent.

### Stale `caldera-autostart.service` pointing at `CyberBlueSOCx`

**Symptom:** `systemctl status caldera-autostart` shows
`WorkingDirectory=/home/ubuntu/CyberBlueSOCx` and the service fails
with `changing to the requested working directory failed: No such file
or directory`.

**Root cause:** Early versions of `cyberblue_install.sh` wrote a typo
into the unit file. The typo is fixed in the repo, but the installer
guards the unit-file write with
`if [ ! -f /etc/systemd/system/caldera-autostart.service ]`, so hosts
that were installed before the fix keep the broken unit on upgrade.

**Fix (manual, one-liner):**
```bash
sudo sed -i 's|/home/ubuntu/CyberBlueSOCx|/home/ubuntu/CyberBlue|g' \
  /etc/systemd/system/caldera-autostart.service
sudo systemctl daemon-reload
sudo systemctl restart caldera-autostart.service
systemctl status caldera-autostart --no-pager
```
Same pattern applies to `docker-networking-fix.service` written by
`fix-docker-external-access.sh` if upgraded from the same bad release.

---

## 🔍 **Advanced Diagnostics**

### Container Deep Dive
```bash
# Get detailed container information
docker inspect [container-name]

# Execute shell in container
docker exec -it [container-name] /bin/bash

# Check container resource limits
docker stats [container-name]
```

### Network Diagnostics
```bash
# Test inter-container connectivity
docker exec portal ping misp-core
docker exec wazuh.manager ping wazuh.indexer

# Check Docker networks
docker network ls
docker network inspect cyber-blue
```

### Storage Diagnostics
```bash
# Check Docker volumes
docker volume ls
docker volume inspect [volume-name]

# Check volume usage
docker system df -v
```

---

## 📊 **Performance Issues**

### High Memory Usage
**Symptoms:**
- System becomes unresponsive
- Containers getting killed (OOMKilled)

**Solutions:**
1. **Adjust Memory Limits:**
   ```yaml
   # In docker-compose.yml
   services:
     opensearch:
       environment:
         - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx2g"  # Reduce from default
   ```

2. **Disable Heavy Services:**
   ```bash
   # Temporarily stop resource-intensive services
   docker-compose stop arkime
   ```

### High CPU Usage
**Solutions:**
1. **Limit CPU Usage:**
   ```yaml
   # In docker-compose.yml
   services:
     service-name:
       deploy:
         resources:
           limits:
             cpus: '0.5'  # Limit to 0.5 CPU cores
   ```

2. **Optimize Configurations:**
   ```bash
   # Reduce Suricata threads
   # Edit suricata.yaml: threading.cpu-affinity sets
   ```

### Disk Space Issues
**Solutions:**
1. **Clean Docker System:**
   ```bash
   # Remove unused containers, networks, images
   docker system prune -a
   
   # Remove unused volumes
   docker volume prune
   ```

2. **Log Rotation:**
   ```bash
   # Configure log rotation in docker-compose.yml
   logging:
     driver: "json-file"
     options:
       max-size: "10m"
       max-file: "3"
   ```

---

## 🛡️ **Security Troubleshooting**

### SSL Certificate Issues
```bash
# Generate new self-signed certificates
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/key.pem \
  -out ssl/cert.pem \
  -subj "/C=US/ST=State/L=City/O=CyberBlue/CN=localhost"
```

### Authentication Problems
```bash
# Reset default passwords
# Edit .env file with new passwords
# Restart affected services
docker-compose restart misp-core wazuh.dashboard
```

---

## 🔄 **Recovery Procedures**

### Complete System Reset
```bash
#!/bin/bash
echo "WARNING: This will destroy all data!"
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
  # Stop all services
  docker-compose down
  
  # Remove all volumes
  docker volume prune -f
  
  # Remove all containers
  docker container prune -f
  
  # Remove all images (optional)
  docker image prune -a -f
  
  # Clean system
  docker system prune -f
  
  # Restart fresh
  ./cyberblue_init.sh
fi
```

### Selective Service Reset
```bash
# Reset specific service (example: MISP)
docker-compose stop misp-core misp-modules db redis
docker volume rm cyberblue_mysql_data
docker-compose up -d db redis
sleep 30
docker-compose up -d misp-core misp-modules
```

---

## 📝 **Log Analysis**

### Centralized Logging
```bash
# View all container logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f [service-name]

# Search logs for errors
docker-compose logs | grep -i error
```

### Log Locations
- **Portal Logs**: `./portal/logs/`
- **Suricata Logs**: `./suricata/logs/`
- **Arkime Logs**: Docker volume `arkime_logs`
- **Wazuh Logs**: Docker volume `wazuh_logs`

---

## 🆘 **Emergency Procedures**

### System Under Attack
1. **Immediate Actions:**
   ```bash
   # Stop external access
   sudo ufw deny in on [external-interface]
   
   # Isolate containers
   docker network disconnect cyber-blue [container-name]
   ```

2. **Evidence Preservation:**
   ```bash
   # Create snapshot
   docker commit [container-name] emergency-snapshot:$(date +%Y%m%d)
   
   # Export logs
   docker logs [container-name] > emergency-logs-$(date +%Y%m%d).log
   ```

### Data Corruption
1. **Stop affected services immediately**
2. **Create snapshots of current state**
3. **Restore from backup**
4. **Analyze corruption cause**

---

## 📞 **Getting Additional Help**

### Community Support
- **GitHub Issues**: [Report bugs and get help](https://github.com/m7siri/cyber-blue-project/issues)
- **Discussions**: [Community Q&A](https://github.com/m7siri/cyber-blue-project/discussions)
- **Security Issues**: Follow SECURITY.md for vulnerability reporting

### Professional Support
- **Tool-Specific Support**: Contact individual tool vendors
- **Enterprise Support**: Consider professional cybersecurity consulting
- **Training**: Look for cybersecurity training programs

### Diagnostic Information to Provide
When seeking help, include:
1. **System Information**: OS, Docker version, available resources
2. **Error Messages**: Complete error logs and messages
3. **Configuration**: Relevant parts of docker-compose.yml and .env
4. **Steps to Reproduce**: Exact steps that led to the issue
5. **Environment**: Development, staging, or production deployment

---

*This troubleshooting guide is continuously updated based on community feedback and identified issues.*
