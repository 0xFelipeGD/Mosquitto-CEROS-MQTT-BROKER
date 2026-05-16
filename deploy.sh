#!/usr/bin/env bash
# Deploy Mosquitto-CEROS — F2 data pipeline broker.
#
# Pre-requisite: ./init.sh já correu (gerou passwords).
#
# Usage:
#   ./deploy.sh [up|down|restart|logs|status]

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

CMD="${1:-up}"

case "$CMD" in
    up)
        echo "[deploy] Starting Mosquitto-CEROS..."
        if [ ! -f mosquitto/passwd ]; then
            echo "[deploy] init.sh hasn't been run yet. Running it now..."
            ./init.sh
        fi
        docker compose up -d
        sleep 3
        docker compose ps
        ;;
    down)
        echo "[deploy] Stopping..."
        docker compose down
        ;;
    restart)
        echo "[deploy] Restarting..."
        docker compose restart
        ;;
    logs)
        docker compose logs -f --tail=100
        ;;
    status)
        docker compose ps
        echo ""
        echo "Health probe (\$SYS/broker/version via health user):"
        docker compose exec -T mosquitto mosquitto_sub -h 127.0.0.1 -p 1883 \
            -u health -P health -t '$SYS/broker/version' -C 1 -W 5 2>&1 \
            || echo "  unhealthy"
        ;;
    *)
        echo "Usage: $0 [up|down|restart|logs|status]"
        exit 1
        ;;
esac
