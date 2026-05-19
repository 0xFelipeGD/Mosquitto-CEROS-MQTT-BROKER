#!/usr/bin/env bash
# wizard.sh — one-command install for Mosquitto-CEROS-MQTT-BROKER (F2).
#
# Prompts for the CEROS user password, generates the passwd file, brings up
# the broker, and prints the URL clients should use.
#
# Re-running is safe (idempotent for passwd if it already exists; just brings
# the broker up).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[wizard]${NC} $*"; }
ok()    { echo -e "${GREEN}[ok]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

log "Mosquitto-CEROS wizard — F2 broker install"
echo ""

# Sudo prefix when not root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || error "This script needs root (or sudo). Re-run as root."
    SUDO="sudo"
fi

# 0. Full setup: bring the host from vanilla to "broker running".
# Honors the wizard contract — never bail with "install X first" when we can install X.

log "Refreshing apt index (apt-get update)..."
$SUDO apt-get update -qq || warn "apt-get update failed (non-fatal if Docker is already installed)."

# Ensure curl + ca-certificates are present (needed for the Docker install script + most VPS bootstrap).
if ! command -v curl >/dev/null 2>&1; then
    log "Installing curl + ca-certificates..."
    $SUDO apt-get install -y curl ca-certificates || error "Failed to install curl."
fi

# Install Docker via the official script if missing. Works on Ubuntu/Debian/CentOS/etc.
# The official script installs docker-ce + the compose v2 plugin in one go,
# so the apt 'docker-compose-v2' fallback below is rarely needed afterwards.
if ! command -v docker >/dev/null 2>&1; then
    log "Docker not found. Installing via official script (https://get.docker.com)..."
    log "  This pulls docker-ce + compose plugin. Takes 1-2 min on a fresh VPS."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh \
        || error "Failed to fetch the Docker install script. Check network / DNS."
    $SUDO sh /tmp/get-docker.sh \
        || error "Docker install script failed. See output above."
    rm -f /tmp/get-docker.sh
    $SUDO systemctl enable --now docker \
        || warn "Could not enable/start docker via systemctl (non-systemd host?). Trying 'service docker start'..."
    if ! $SUDO systemctl is-active --quiet docker 2>/dev/null; then
        $SUDO service docker start >/dev/null 2>&1 || true
    fi
    ok "Docker installed: $(docker --version 2>/dev/null || echo 'not in PATH yet')"
else
    ok "Docker already present: $(docker --version)"
fi

# Confirm the daemon answers (catches "installed but not running" and missing perms).
if ! $SUDO docker info >/dev/null 2>&1; then
    warn "Docker daemon not responding. Trying to start it..."
    $SUDO systemctl start docker >/dev/null 2>&1 || $SUDO service docker start >/dev/null 2>&1 || true
    sleep 2
    $SUDO docker info >/dev/null 2>&1 \
        || error "Docker daemon still not responding. Run 'sudo systemctl status docker' to investigate."
fi

# Auto-install docker-compose-v2 if the plugin is missing. The official Docker
# script normally bundles the compose plugin, but some hosts already had the
# older 'docker.io' apt package — in that case the plugin is absent and we
# install it from Ubuntu universe (works on jammy 22.04 + noble 24.04).
if ! docker compose version >/dev/null 2>&1; then
    warn "Docker Compose v2 plugin not found. Installing 'docker-compose-v2' via apt..."
    $SUDO apt-get install -y docker-compose-v2 \
        || error "Failed to install docker-compose-v2. Run manually: sudo apt install docker-compose-v2"
    docker compose version >/dev/null 2>&1 \
        || error "docker-compose-v2 installed but 'docker compose' still not available. Investigate manually."
    ok "docker-compose-v2 installed"
fi

# Smoke test the daemon. Pulls a 13 kB image once; idempotent thereafter.
log "Verifying Docker works (hello-world)..."
if $SUDO docker run --rm hello-world >/dev/null 2>&1; then
    ok "Docker is healthy."
else
    warn "hello-world smoke test failed — network or daemon issue. Trying to proceed anyway."
fi

# 1. Prompt for password (only if passwd doesn't already exist)
if [ -f mosquitto/passwd ]; then
    warn "mosquitto/passwd already exists; keeping it. Delete it to regenerate."
else
    echo -n "Enter password for the 'ceros' MQTT user: "
    read -rs CEROS_PWD
    echo
    if [ -z "$CEROS_PWD" ]; then
        error "Empty password — aborting."
    fi
    CEROS_PWD="$CEROS_PWD" ./init.sh
fi

# 2. Optional firewall opening (Ubuntu/Debian with ufw)
if command -v ufw >/dev/null 2>&1 && $SUDO ufw status >/dev/null 2>&1; then
    echo ""
    read -rp "Open ports 1883 + 9001 with ufw? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        $SUDO ufw allow 1883/tcp
        $SUDO ufw allow 9001/tcp
        ok "Firewall rules added"
    fi
fi

# 3. Bring up the broker
log "Starting broker..."
./deploy.sh up
sleep 3
./deploy.sh status

# 4. Print useful URLs
HOST=$(hostname -I 2>/dev/null | awk '{print $1}')
HOST="${HOST:-<this-host-ip>}"
echo ""
ok "================================================"
ok "  Broker is up. Use these URLs on the clients:"
ok ""
ok "  Jetson (mqtt_client):     mqtt://${HOST}:1883"
ok "  Operator PC (Electron):   ws://${HOST}:9001"
ok "  Username:                 ceros"
ok "  Password:                 <what you just typed>"
ok "================================================"
echo ""
echo "Next: install Jetson-ROS2-CEROS and RCS-ROS2-CEROS using their own wizard.sh."
