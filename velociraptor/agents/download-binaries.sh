#!/bin/bash
# CyberBlue - Download Velociraptor Agent Binaries
# This script downloads official Velociraptor binaries for agent deployment
# Run this during CyberBlue installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARIES_DIR="$SCRIPT_DIR/binaries"

echo "========================================="
echo "Downloading Velociraptor Agent Binaries"
echo "========================================="
echo ""

# Create binaries directory
mkdir -p "$BINARIES_DIR"
cd "$BINARIES_DIR"

# Velociraptor version
VELOCI_VERSION="v0.75"
VELOCI_PATCH="v0.75.2"
BASE_URL="https://github.com/Velocidex/velociraptor/releases/download/${VELOCI_VERSION}"

echo "[*] Downloading Velociraptor ${VELOCI_PATCH} binaries..."
echo ""

# Windows (amd64)
echo "[1/5] Downloading Windows binary (66 MB)..."
curl -L -o velociraptor-windows.exe "${BASE_URL}/velociraptor-${VELOCI_PATCH}-windows-amd64.exe" \
    || { echo "Failed to download Windows binary"; exit 1; }
echo "      ✓ velociraptor-windows.exe downloaded"

# Linux amd64 (default filename kept for portal backwards-compat)
echo "[2/5] Downloading Linux amd64 binary (70 MB)..."
curl -L -o velociraptor-linux "${BASE_URL}/velociraptor-${VELOCI_PATCH}-linux-amd64" \
    || { echo "Failed to download Linux amd64 binary"; exit 1; }
chmod +x velociraptor-linux
echo "      ✓ velociraptor-linux downloaded"

# Linux arm64 (for Apple Silicon Docker hosts, Raspberry Pi, Graviton, etc.)
echo "[3/5] Downloading Linux arm64 binary (~65 MB)..."
curl -L -o velociraptor-linux-arm64 "${BASE_URL}/velociraptor-${VELOCI_PATCH}-linux-arm64" \
    || { echo "[WARN] Failed to download Linux arm64 binary - continuing (arm64 endpoints will not be deployable)"; }
[ -s velociraptor-linux-arm64 ] && chmod +x velociraptor-linux-arm64
echo "      ✓ velociraptor-linux-arm64 downloaded"

# macOS Intel
echo "[4/5] Downloading macOS Intel binary (66 MB)..."
curl -L -o velociraptor-macos-intel "${BASE_URL}/velociraptor-${VELOCI_PATCH}-darwin-amd64" \
    || { echo "Failed to download macOS Intel binary"; exit 1; }
chmod +x velociraptor-macos-intel
echo "      ✓ velociraptor-macos-intel downloaded"

# macOS ARM (Apple Silicon)
echo "[5/5] Downloading macOS ARM binary (63 MB)..."
curl -L -o velociraptor-macos-arm "${BASE_URL}/velociraptor-${VELOCI_PATCH}-darwin-arm64" \
    || { echo "Failed to download macOS ARM binary"; exit 1; }
chmod +x velociraptor-macos-arm
echo "      ✓ velociraptor-macos-arm downloaded"

echo ""
echo "========================================="
echo "Download Complete!"
echo "========================================="
echo ""

# Fix file ownership to ensure portal can read files
# Detect the actual user (works with or without sudo)
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    # Script was run with sudo - chown to the real user
    REAL_USER="$SUDO_USER"
    REAL_GROUP=$(id -gn $SUDO_USER)
    echo "[*] Fixing file ownership for user: $REAL_USER (run with sudo)"
    chown -R "$REAL_USER:$REAL_GROUP" "$SCRIPT_DIR"
    echo "    ✓ Ownership set to $REAL_USER:$REAL_GROUP"
elif [ "$(id -u)" = "0" ]; then
    # Running as root directly (no SUDO_USER) - find the actual install user
    # Get the owner of the parent CyberBlue directory
    CYBERBLUE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
    REAL_USER=$(stat -c '%U' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Su' "$CYBERBLUE_DIR" 2>/dev/null || echo "ubuntu")
    REAL_GROUP=$(stat -c '%G' "$CYBERBLUE_DIR" 2>/dev/null || stat -f '%Sg' "$CYBERBLUE_DIR" 2>/dev/null || echo "$REAL_USER")
    echo "[*] Fixing file ownership for user: $REAL_USER (detected from directory owner)"
    chown -R "$REAL_USER:$REAL_GROUP" "$SCRIPT_DIR"
    echo "    ✓ Ownership set to $REAL_USER:$REAL_GROUP"
else
    # Running as regular user - files should already be owned correctly
    CURRENT_USER=$(whoami)
    echo "[*] Files owned by: $CURRENT_USER (no sudo - should be correct)"
fi

echo "Downloaded binaries:"
ls -lh "$BINARIES_DIR"
echo ""
echo "Total size: $(du -sh "$BINARIES_DIR" | cut -f1)"
echo ""
echo "Agent deployment system is now ready!"
echo "Users can generate and download agent packages from the portal."
echo ""


