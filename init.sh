#!/usr/bin/env bash
# Initialize Mosquitto-CEROS — generate user/password file for F2 deployment.
#
# Run ONCE on first deploy. Idempotent (skips existing files).
#
# Env vars to override defaults:
#   CEROS_PWD=...   (password for the 'ceros' user; default 'changeme')
#   HEALTH_PWD=...  (default 'health')
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

log "Mosquitto-CEROS initialization (F2 simple auth)"

# Generate password file if missing
if [ ! -f mosquitto/passwd ]; then
    log "Generating password file with 2 users (ceros, health)..."

    CEROS_PWD="${CEROS_PWD:-changeme}"
    HEALTH_PWD="${HEALTH_PWD:-health}"

    docker run --rm -v "$(pwd)/mosquitto:/mosquitto-host" eclipse-mosquitto:2.0 \
        sh -c "
            echo 'ceros:$CEROS_PWD' > /tmp/passwd
            echo 'health:$HEALTH_PWD' >> /tmp/passwd
            mosquitto_passwd -U /tmp/passwd
            cat /tmp/passwd > /mosquitto-host/passwd
            chmod 0700 /mosquitto-host/passwd
            chown 1883:1883 /mosquitto-host/passwd 2>/dev/null || true
        "
    ok "Password file created"
    if [ "$CEROS_PWD" = "changeme" ]; then
        warn "Default password is 'changeme'. CHANGE IT (rerun with CEROS_PWD=... after delete)."
    fi
else
    warn "Password file already exists — skipping (delete mosquitto/passwd to regenerate)"
fi

# Verify structure
log "Verifying structure..."
test -f mosquitto/mosquitto.conf || { echo "Missing mosquitto/mosquitto.conf"; exit 1; }
test -f mosquitto/acl || { echo "Missing mosquitto/acl"; exit 1; }
ok "Structure OK"

ok "================================="
ok "Mosquitto-CEROS initialized!"
ok "================================="
echo ""
echo "Next steps:"
echo "  - ./deploy.sh up       (start the broker)"
echo "  - ./deploy.sh status   (verify it's healthy)"
echo ""
