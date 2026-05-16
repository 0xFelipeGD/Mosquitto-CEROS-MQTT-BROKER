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

# 0. Sanity
command -v docker >/dev/null 2>&1 || error "Docker is required. Install Docker first."
docker compose version >/dev/null 2>&1 || error "Docker Compose v2 plugin is required."

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
if command -v ufw >/dev/null 2>&1 && ufw status >/dev/null 2>&1; then
    echo ""
    read -rp "Open ports 1883 + 9001 with ufw? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        sudo ufw allow 1883/tcp
        sudo ufw allow 9001/tcp
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
