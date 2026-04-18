#!/usr/bin/env bash
#
# CyberBlueSOC - one-shot post-prereqs initializer
#
# Runs, in order:
#   1. cyberblue_install.sh         (Docker container stack)
#   2. tools/native/install.sh      (native blue-team toolkit)
#                                   -> auto-chains install-desktop.sh
#                                      when a desktop session is present
#
# Assumptions:
#   * Ubuntu 22.04 / 24.04 (amd64 or arm64).
#   * OS prerequisites already installed via one of:
#         - install-prerequisites.sh / setup-prerequisites.sh  (server box)
#         - iso/scripts/buildbox-bootstrap.sh                  (workstation /
#           build-box / ISO first-boot)
#   * Docker daemon running and current user in the `docker` group.
#   * This repo is checked out and you are inside its root.
#
# On a true fresh box, run the OS prereqs FIRST, re-login so the `docker`
# group takes effect, THEN run this script. Both halves are safe to re-run.
#
# Idempotent: each downstream script is independently idempotent; re-running
# this umbrella is safe.
#
# Architecture note: handles amd64 and arm64 transparently. Known arm64
# exceptions (fleet, tenzir, zui, bulk_extractor, sysmonforlinux) are
# documented in ENHANCEMENTS.md and the cyberblue-multi-arch-policy rule.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

say()  { echo -e "${BLUE}==>${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()  { echo -e "${RED}[FATAL]${NC} $*" >&2; exit 1; }

[ -f ./cyberblue_install.sh ] || die "cyberblue_install.sh not found - run this from the repo root"
[ -f ./tools/native/install.sh ] || die "tools/native/install.sh not found - run this from the repo root"

if ! command -v docker >/dev/null 2>&1; then
  die "docker not found. Run install-prerequisites.sh (server) or iso/scripts/buildbox-bootstrap.sh (workstation) first."
fi
if ! docker info >/dev/null 2>&1; then
  die "docker daemon not reachable by this user. If you were just added to the 'docker' group, log out + back in and rerun."
fi

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
say "CyberBlueSOC initializer starting on ${ARCH}"
say "Repo root: ${REPO_ROOT}"

# ---------- Stage 1: Docker container stack ----------
say "Stage 1/2: Docker container stack (cyberblue_install.sh)"
if [ "$(id -u)" -eq 0 ]; then
  warn "Running as root; cyberblue_install.sh is designed to run as a normal user with sudo."
fi
./cyberblue_install.sh
ok "Stage 1 complete"

# ---------- Stage 2: Native blue-team toolkit (+ desktop UX if applicable) ----------
say "Stage 2/2: Native blue-team toolkit (tools/native/install.sh)"
if [ "$(id -u)" -ne 0 ]; then
  sudo bash ./tools/native/install.sh
else
  bash ./tools/native/install.sh
fi
ok "Stage 2 complete"

say "CyberBlueSOC initialization finished."
say "Container stack:  sudo docker compose ps"
say "Native toolkit:   ls /opt/soc-tools ; cyberblue status"
