#!/usr/bin/env bash
# Initialize Mosquitto-Broker-ROS2 — generate self-signed TLS certs + user passwords.
#
# Run ONCE on first deploy. Idempotent (skips existing files).
#
# Usage:
#   ./init.sh

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${BLUE}[init]${NC} $*"; }
ok()   { echo -e "${GREEN}[ok]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }

log "Mosquitto-Broker-ROS2 initialization"

# 1. Generate certs if missing
if [ ! -f certs/ca.crt ]; then
    log "Generating self-signed CA + server certs (good for dev / private use)..."
    log "For production, use Let's Encrypt or a real CA."
    mkdir -p certs

    # CA
    openssl req -new -x509 -days 3650 -extensions v3_ca -keyout certs/ca.key -out certs/ca.crt \
        -subj "/C=PT/ST=Lisboa/O=ROS2-RCS/CN=ros2-rcs-CA" \
        -nodes

    # Server cert
    openssl genrsa -out certs/server.key 4096
    openssl req -new -key certs/server.key -out certs/server.csr \
        -subj "/C=PT/ST=Lisboa/O=ROS2-RCS/CN=ros2-rcs.example.com" \
        -nodes
    openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
        -out certs/server.crt -days 3650

    rm certs/server.csr certs/ca.srl 2>/dev/null || true
    chmod 644 certs/*.crt
    chmod 600 certs/*.key
    ok "Certs generated"
else
    warn "Certs already exist — skipping"
fi

# 2. Generate password file if missing
if [ ! -f mosquitto/passwd ]; then
    log "Generating password file with 3 users..."
    log "NOTE: edit these passwords before production deploy!"

    # Default passwords (CHANGE THESE in production!)
    RCS_PWD="${RCS_OPERATOR_PWD:-rcs_change_me}"
    UGV_PWD="${UGV_CLIENT_PWD:-ugv_change_me}"
    HEALTH_PWD="${HEALTH_PWD:-health}"

    # Create empty file
    touch mosquitto/passwd

    # Use mosquitto_passwd via container (the host may not have it installed)
    docker run --rm -v "$(pwd)/mosquitto/passwd:/passwd" eclipse-mosquitto:2.0 \
        sh -c "echo 'rcs_operator:$RCS_PWD' > /tmp/passwd && \
               echo 'ugv_client:$UGV_PWD' >> /tmp/passwd && \
               echo 'health:$HEALTH_PWD' >> /tmp/passwd && \
               mosquitto_passwd -U /tmp/passwd && \
               cat /tmp/passwd > /passwd"
    chmod 600 mosquitto/passwd
    ok "Password file created (chmod 600)"
    warn "Default passwords are 'rcs_change_me', 'ugv_change_me', 'health'. CHANGE THEM!"
else
    warn "Password file already exists — skipping"
fi

# 3. Verify structure
log "Verifying structure..."
test -f mosquitto/mosquitto.conf || (log "Missing mosquitto/mosquitto.conf"; exit 1)
test -f mosquitto/acl || (log "Missing mosquitto/acl"; exit 1)
test -f coturn/turnserver.conf || (log "Missing coturn/turnserver.conf"; exit 1)
ok "Structure OK"

ok "================================="
ok "Mosquitto-Broker-ROS2 initialized!"
ok "================================="
echo ""
echo "Next steps:"
echo "  1. Edit certs and passwords for production"
echo "  2. Edit coturn/turnserver.conf — set relay-ip to your VPS public IP"
echo "  3. ./deploy.sh  (or manually: docker compose up -d)"
echo ""
echo "Pra Phase 1-7, este broker NÃO precisa estar deployed. Só em Phase 8."
