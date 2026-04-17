#!/bin/bash
# ============================================================================
# CyberBlueSOC - Wazuh arm64 image rebuild helper
# ============================================================================
# Wazuh does not publish linux/arm64 variants of wazuh-manager, wazuh-indexer,
# or wazuh-dashboard on Docker Hub as of 2026-04. However, they do ship arm64
# native packages via packages.wazuh.com and their vendored Dockerfiles at
# CyberBlue/wazuh/build-docker-images/ are arch-agnostic (after the one-line
# s6-overlay fix in wazuh-manager/Dockerfile).
#
# This script uses `docker buildx` to build the three images locally on the
# current host (expected: arm64), tags them as `wazuh/wazuh-<kind>:<version>`
# WITHOUT a `-arm64` suffix so the existing docker-compose.yml references in
# CyberBlue/docker-compose.yml (lines ~576, 622, 650) find them as-is.
#
# On amd64 hosts this script is a no-op - compose pulls upstream images from
# Docker Hub directly.
#
# Usage:
#   bash wazuh/build-arm64-images.sh
#
# Called automatically from cyberblue_install.sh Step 2.9a on arm64 hosts.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-docker-images"

WAZUH_IMAGE_VERSION="4.12.0"
WAZUH_TAG_REVISION="1"
FILEBEAT_MODULE_VERSION="0.4"
WAZUH_UI_REVISION="${WAZUH_TAG_REVISION}"

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in
    amd64|x86_64)
        echo "[wazuh-arm64-build] Host is ${ARCH} - upstream images work, nothing to build. Exiting."
        exit 0
        ;;
    arm64|aarch64) ;;
    *)
        echo "[wazuh-arm64-build] Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

echo "========================================================================"
echo "[wazuh-arm64-build] Building Wazuh ${WAZUH_IMAGE_VERSION} images for arm64"
echo "========================================================================"

if [ ! -d "$BUILD_DIR" ]; then
    echo "[wazuh-arm64-build] ERROR: expected build context at $BUILD_DIR" >&2
    exit 1
fi

# Wazuh's own build flow derives these from versions - replicate minimally.
WAZUH_VERSION_NUM="$(echo "$WAZUH_IMAGE_VERSION" | sed -e 's/\.//g')"
WAZUH_FILEBEAT_MODULE="wazuh-filebeat-${FILEBEAT_MODULE_VERSION}.tar.gz"

# Pick the filebeat template branch that actually exists in wazuh/wazuh.
if curl --output /dev/null --silent --head --fail "https://github.com/wazuh/wazuh/tree/v${WAZUH_IMAGE_VERSION}"; then
    FILEBEAT_TEMPLATE_BRANCH="v${WAZUH_IMAGE_VERSION}"
else
    FILEBEAT_TEMPLATE_BRANCH="${WAZUH_IMAGE_VERSION}"
fi
echo "[wazuh-arm64-build] Using filebeat template branch: $FILEBEAT_TEMPLATE_BRANCH"

# Ensure buildx is available and a suitable builder is active.
if ! docker buildx version >/dev/null 2>&1; then
    echo "[wazuh-arm64-build] ERROR: docker buildx not available. Install docker-buildx-plugin." >&2
    exit 1
fi
docker buildx inspect cyberblue-builder >/dev/null 2>&1 || \
    docker buildx create --name cyberblue-builder --driver docker-container --use >/dev/null
docker buildx use cyberblue-builder

build_one() {
    local service="$1"        # wazuh-manager | wazuh-indexer | wazuh-dashboard
    local tag="wazuh/${service}:${WAZUH_IMAGE_VERSION}"
    local context="${BUILD_DIR}/${service}"

    echo
    echo "[wazuh-arm64-build] ---- ${service} ----"
    echo "[wazuh-arm64-build] context: ${context}"
    echo "[wazuh-arm64-build] tag:     ${tag}"

    # Common args
    local args=(
        --platform linux/arm64
        --load
        --build-arg "WAZUH_VERSION=${WAZUH_VERSION_NUM}"
        --build-arg "WAZUH_TAG_REVISION=${WAZUH_TAG_REVISION}"
        -t "${tag}"
    )

    case "$service" in
        wazuh-manager)
            args+=(
                --build-arg "FILEBEAT_TEMPLATE_BRANCH=${FILEBEAT_TEMPLATE_BRANCH}"
                --build-arg "WAZUH_FILEBEAT_MODULE=${WAZUH_FILEBEAT_MODULE}"
            )
            ;;
        wazuh-dashboard)
            args+=(--build-arg "WAZUH_UI_REVISION=${WAZUH_UI_REVISION}")
            ;;
    esac

    docker buildx build "${args[@]}" "${context}"
}

build_one wazuh-indexer
build_one wazuh-manager
build_one wazuh-dashboard

echo
echo "========================================================================"
echo "[wazuh-arm64-build] Complete. Images:"
docker images | grep -E "^wazuh/(wazuh-manager|wazuh-indexer|wazuh-dashboard)\s+${WAZUH_IMAGE_VERSION}" || true
echo "========================================================================"
