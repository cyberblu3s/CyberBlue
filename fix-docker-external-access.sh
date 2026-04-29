#!/bin/bash

# Universal Docker External Access Fix Script
# This script fixes Docker container external access issues on any Ubuntu system
# Works on AWS, Azure, GCP, bare metal, or any other deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_header() {
    echo -e "${BLUE}🔧 $1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

# Function to detect primary network interface dynamically
detect_primary_interface() {
    print_info "Detecting primary network interface..."
    
    # Method 1: Try to get the default route interface (most reliable)
    PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Method 2: Fallback to first active non-loopback interface with IP
    if [ -z "$PRIMARY_INTERFACE" ]; then
        print_warning "No default route found, trying alternative detection..."
        PRIMARY_INTERFACE=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1 | xargs -I {} ip -4 addr show | grep -B2 {} | grep -oP '(?<=^\d+:\s)[^:@]+' | head -1)
    fi
    
    # Method 3: Final fallback to any UP interface except loopback
    if [ -z "$PRIMARY_INTERFACE" ]; then
        print_warning "Trying final fallback method..."
        PRIMARY_INTERFACE=$(ip link show | grep -E '^[0-9]+:' | grep 'state UP' | grep -v lo | awk -F': ' '{print $2}' | head -1 | cut -d'@' -f1)
    fi
    
    # Method 4: Common interface names fallback
    if [ -z "$PRIMARY_INTERFACE" ]; then
        print_warning "Using common interface name detection..."
        for iface in eth0 ens5 ens3 enp0s3 enp0s8 ens160 ens192; do
            if ip link show "$iface" >/dev/null 2>&1 && ip link show "$iface" | grep -q "state UP"; then
                PRIMARY_INTERFACE="$iface"
                break
            fi
        done
    fi
    
    if [ -z "$PRIMARY_INTERFACE" ]; then
        print_error "Could not detect any suitable network interface."
        print_info "Available interfaces:"
        ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print "   - " $2}' | sed 's/@.*$//'
        echo ""
        read -p "Please enter your primary network interface name: " PRIMARY_INTERFACE
        
        if [ -z "$PRIMARY_INTERFACE" ]; then
            print_error "No interface specified. Exiting."
            exit 1
        fi
    fi
    
    # Validate the interface exists and is UP
    if ! ip link show "$PRIMARY_INTERFACE" >/dev/null 2>&1; then
        print_error "Interface '$PRIMARY_INTERFACE' does not exist!"
        exit 1
    fi
    
    if ! ip link show "$PRIMARY_INTERFACE" | grep -q "state UP"; then
        print_warning "Interface '$PRIMARY_INTERFACE' is not UP, but continuing..."
    fi
    
    print_status "Detected/Using primary interface: $PRIMARY_INTERFACE"
    
    # Get interface IP for information
    INTERFACE_IP=$(ip -4 addr show "$PRIMARY_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [ -n "$INTERFACE_IP" ]; then
        print_info "Interface IP: $INTERFACE_IP"
    fi
}

# Function to detect Docker bridge interfaces
detect_docker_bridges() {
    print_info "Detecting Docker bridge interfaces..."
    
    DOCKER_BRIDGES=$(ip link show | grep -E 'br-[a-f0-9]+|docker0' | awk -F': ' '{print $2}' | cut -d'@' -f1)
    
    if [ -z "$DOCKER_BRIDGES" ]; then
        print_warning "No Docker bridge interfaces found. Docker might not be running."
        print_info "Starting Docker service..."
        sudo systemctl start docker
        sleep 5
        DOCKER_BRIDGES=$(ip link show | grep -E 'br-[a-f0-9]+|docker0' | awk -F': ' '{print $2}' | cut -d'@' -f1)
    fi
    
    if [ -n "$DOCKER_BRIDGES" ]; then
        print_status "Found Docker bridges: $(echo $DOCKER_BRIDGES | tr '\n' ' ')"
    else
        print_error "No Docker bridges found even after starting Docker!"
        exit 1
    fi
}

# Function to backup current iptables rules
backup_iptables() {
    print_info "Creating backup of current iptables rules..."
    BACKUP_FILE="/tmp/iptables-backup-$(date +%Y%m%d-%H%M%S).rules"
    sudo iptables-save > "$BACKUP_FILE"
    print_status "Backup saved to: $BACKUP_FILE"
}

# Function to check if rule already exists
rule_exists() {
    local rule="$1"
    sudo iptables -C $rule >/dev/null 2>&1
}

# Function to apply Docker networking fixes
apply_docker_fixes() {
    print_header "Applying Docker External Access Fixes"
    
    # Check current FORWARD policy
    CURRENT_POLICY=$(sudo iptables -L FORWARD | head -1 | grep -oP '(?<=policy )[A-Z]+')
    print_info "Current FORWARD policy: $CURRENT_POLICY"
    
    # Fix 1: Allow forwarding from external interface to Docker bridges
    print_info "Adding FORWARD rule: external interface → Docker bridges"
    for bridge in $DOCKER_BRIDGES; do
        if ! rule_exists "FORWARD -i $PRIMARY_INTERFACE -o $bridge -j ACCEPT"; then
            sudo iptables -I FORWARD -i "$PRIMARY_INTERFACE" -o "$bridge" -j ACCEPT
            print_status "Added rule: $PRIMARY_INTERFACE → $bridge"
        else
            print_info "Rule already exists: $PRIMARY_INTERFACE → $bridge"
        fi
    done
    
    # Fix 2: Allow return traffic from Docker bridges to external interface
    print_info "Adding FORWARD rule: Docker bridges → external interface"
    for bridge in $DOCKER_BRIDGES; do
        if ! rule_exists "FORWARD -i $bridge -o $PRIMARY_INTERFACE -j ACCEPT"; then
            sudo iptables -I FORWARD -i "$bridge" -o "$PRIMARY_INTERFACE" -j ACCEPT
            print_status "Added rule: $bridge → $PRIMARY_INTERFACE"
        else
            print_info "Rule already exists: $bridge → $PRIMARY_INTERFACE"
        fi
    done
    
    # Fix 3: Set FORWARD policy to ACCEPT if it's DROP
    if [ "$CURRENT_POLICY" = "DROP" ]; then
        print_info "Changing FORWARD policy from DROP to ACCEPT"
        sudo iptables -P FORWARD ACCEPT
        print_status "FORWARD policy changed to ACCEPT"
    else
        print_status "FORWARD policy already set to ACCEPT"
    fi
    
    # Fix 4: Ensure Docker-specific rules for common container ports
    print_info "Adding specific rules for common container ports..."
    
    # Common web ports used by SOC tools
    for port in 80 443 5443 7001 7002 7003 7004 7005 7006 7007 7008 7009; do
        # Allow external to container
        if ! rule_exists "FORWARD -i $PRIMARY_INTERFACE -p tcp --dport $port -j ACCEPT"; then
            sudo iptables -I FORWARD -i "$PRIMARY_INTERFACE" -p tcp --dport $port -j ACCEPT
        fi
        # Allow container to external (return traffic)
        if ! rule_exists "FORWARD -o $PRIMARY_INTERFACE -p tcp --sport $port -j ACCEPT"; then
            sudo iptables -I FORWARD -o "$PRIMARY_INTERFACE" -p tcp --sport $port -j ACCEPT
        fi
    done
    print_status "Added rules for common SOC tool ports"
}

# Function to make rules persistent
make_persistent() {
    print_header "Making Rules Persistent"
    
    # Check if iptables-persistent is installed
    if ! dpkg -l | grep -q iptables-persistent; then
        print_info "Installing iptables-persistent..."
        sudo apt update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive sudo apt install -y iptables-persistent >/dev/null 2>&1
        print_status "iptables-persistent installed"
    else
        print_status "iptables-persistent already installed"
    fi
    
    # Save current rules
    print_info "Saving iptables rules..."
    sudo mkdir -p /etc/iptables
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
    print_status "Rules saved to /etc/iptables/rules.v4"
    
    # Enable netfilter-persistent service
    sudo systemctl enable netfilter-persistent >/dev/null 2>&1
    print_status "netfilter-persistent service enabled"
}

# Function to test connectivity
test_connectivity() {
    print_header "Testing Container Connectivity"
    
    # Get server IP
    SERVER_IP=$(ip -4 addr show "$PRIMARY_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    
    if [ -n "$SERVER_IP" ]; then
        print_info "Testing connectivity to $SERVER_IP..."
        
        # Test some common ports
        for port in 7003 7008 7004; do
            print_info "Testing port $port..."
            if timeout 5 bash -c "</dev/tcp/$SERVER_IP/$port" >/dev/null 2>&1; then
                print_status "Port $port is accessible"
            else
                print_warning "Port $port is not responding (service might not be running)"
            fi
        done
    else
        print_warning "Could not determine server IP for testing"
    fi
}

# Function to display current iptables status
show_status() {
    print_header "Current iptables Configuration"
    
    echo "FORWARD Chain Policy:"
    sudo iptables -L FORWARD | head -1
    echo ""
    
    echo "FORWARD Chain Rules (first 10):"
    sudo iptables -L FORWARD -n --line-numbers | head -11
    echo ""
    
    echo "NAT Rules for Docker:"
    sudo iptables -t nat -L DOCKER -n | grep -E "DNAT|REDIRECT" | head -5
    echo ""
    
    echo "Docker Bridge Interfaces:"
    ip link show | grep -E 'br-[a-f0-9]+|docker0' | awk -F': ' '{print "   - " $2}' | cut -d'@' -f1
}

# Function to create systemd service for applying rules on boot
create_startup_service() {
    print_header "Creating Startup Service"
    
    SERVICE_FILE="/etc/systemd/system/docker-networking-fix.service"
    
    sudo tee "$SERVICE_FILE" >/dev/null << EOF
[Unit]
Description=Docker External Access Networking Fix
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/home/ubuntu/CyberBlue/fix-docker-external-access.sh --apply-only
User=root

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable docker-networking-fix.service >/dev/null 2>&1
    print_status "Created and enabled docker-networking-fix.service"
}

# Main execution
main() {
    print_header "Universal Docker External Access Fix"
    echo "This script fixes Docker container external access on any Ubuntu system"
    echo "Supports: AWS EC2, Azure VMs, GCP, bare metal, VirtualBox, VMware, etc."
    echo ""
    
    # Check if running as root or with sudo
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root. This is acceptable for system configuration."
    elif ! sudo -n true 2>/dev/null; then
        print_error "This script requires sudo privileges. Please run with sudo or as root."
        exit 1
    fi
    
    # Parse arguments
    APPLY_ONLY=false
    SKIP_PERSISTENT=false
    SKIP_SERVICE=false
    
    for arg in "$@"; do
        case $arg in
            --apply-only)
                APPLY_ONLY=true
                shift
                ;;
            --skip-persistent)
                SKIP_PERSISTENT=true
                shift
                ;;
            --skip-service)
                SKIP_SERVICE=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --apply-only      Only apply iptables rules (for systemd service)"
                echo "  --skip-persistent Skip making rules persistent"
                echo "  --skip-service    Skip creating systemd service"
                echo "  -h, --help        Show this help message"
                echo ""
                echo "Examples:"
                echo "  $0                # Full setup with all features"
                echo "  $0 --skip-service # Setup without systemd service"
                exit 0
                ;;
        esac
    done
    
    # Step 1: Detect network interface
    detect_primary_interface
    
    # Step 2: Detect Docker bridges
    detect_docker_bridges
    
    # Step 3: Backup current rules (unless apply-only mode)
    if [ "$APPLY_ONLY" = false ]; then
        backup_iptables
    fi
    
    # Step 4: Apply fixes
    apply_docker_fixes
    
    # Step 5: Make persistent (unless skipped or apply-only mode)
    if [ "$APPLY_ONLY" = false ] && [ "$SKIP_PERSISTENT" = false ]; then
        make_persistent
    fi
    
    # Step 6: Create systemd service (unless skipped or apply-only mode)
    if [ "$APPLY_ONLY" = false ] && [ "$SKIP_SERVICE" = false ]; then
        create_startup_service
    fi
    
    # Step 7: Show status
    if [ "$APPLY_ONLY" = false ]; then
        show_status
    fi
    
    # Step 8: Test connectivity (unless apply-only mode)
    if [ "$APPLY_ONLY" = false ]; then
        test_connectivity
    fi
    
    # Final summary
    echo ""
    print_header "Docker External Access Fix Complete!"
    
    if [ -n "$INTERFACE_IP" ]; then
        echo "🌐 Your server IP: $INTERFACE_IP"
        echo "🔗 Test MISP access: https://$INTERFACE_IP:7003"
        echo "👤 MISP credentials: admin@admin.test / admin"
    fi
    
    echo ""
    print_status "Docker containers should now be accessible externally"
    print_status "Rules will persist across reboots"
    
    if [ "$SKIP_SERVICE" = false ] && [ "$APPLY_ONLY" = false ]; then
        print_status "Systemd service created for automatic rule application"
    fi
    
    echo ""
    print_info "Troubleshooting commands:"
    echo "  - Check rules: sudo iptables -L FORWARD -n"
    echo "  - Test ports: sudo ss -tlnp | grep :PORT"
    echo "  - View logs: sudo journalctl -u docker-networking-fix"
    echo "  - Reapply: $0 --apply-only"
}

# Detect platform for informational purposes
detect_platform() {
    if [ -f /sys/hypervisor/uuid ] && grep -q "^ec2" /sys/hypervisor/uuid 2>/dev/null; then
        echo "AWS EC2"
    elif [ -f /sys/class/dmi/id/sys_vendor ]; then
        case $(cat /sys/class/dmi/id/sys_vendor 2>/dev/null) in
            "Microsoft Corporation") echo "Azure" ;;
            "Google") echo "Google Cloud" ;;
            "QEMU") echo "QEMU/KVM" ;;
            "VMware, Inc.") echo "VMware" ;;
            "innotek GmbH") echo "VirtualBox" ;;
            *) echo "Physical/Other" ;;
        esac
    else
        echo "Unknown"
    fi
}

# Show platform info
PLATFORM=$(detect_platform)
print_info "Detected platform: $PLATFORM"

# Run main function
main "$@"



