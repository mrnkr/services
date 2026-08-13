#!/usr/bin/env bash
# Gen systemd system unit for docker-compose project.
# Pattern: system unit (multi-user.target, no linger needed), process runs as
# non-root User=/Group=docker, direct docker compose calls.
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") -d <compose-dir> -u <run-as-user> [-f <compose-file>] [-n <service-name>]

  -d  dir containing docker-compose.yml (required)
  -u  user to run compose as (required)
  -f  compose filename (default: docker-compose.yml)
  -n  service name (default: dir basename)

requires sudo (writes to /etc/systemd/system/).
EOF
  exit 1
}

COMPOSE_FILE="docker-compose.yml"
SERVICE_NAME=""
RUN_AS_USER=""

while getopts "d:f:n:u:h" opt; do
  case "$opt" in
    d) COMPOSE_DIR="$OPTARG" ;;
    f) COMPOSE_FILE="$OPTARG" ;;
    n) SERVICE_NAME="$OPTARG" ;;
    u) RUN_AS_USER="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

[[ -z "${COMPOSE_DIR:-}" ]] && usage
[[ -z "${RUN_AS_USER:-}" ]] && usage
[[ $EUID -eq 0 ]] || { echo "run with sudo (writes /etc/systemd/system/)" >&2; exit 1; }

COMPOSE_DIR="$(cd "$COMPOSE_DIR" && pwd)"
[[ -f "$COMPOSE_DIR/$COMPOSE_FILE" ]] || { echo "no $COMPOSE_FILE in $COMPOSE_DIR" >&2; exit 1; }

SERVICE_NAME="${SERVICE_NAME:-$(basename "$COMPOSE_DIR")}"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose plugin not found" >&2; exit 1; }
id -nG "$RUN_AS_USER" | grep -qw docker || echo "warn: $RUN_AS_USER not in docker group yet" >&2

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=${SERVICE_NAME} docker compose
Requires=docker.service
After=docker.service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${COMPOSE_DIR}
ExecStart=/usr/bin/docker compose -f ${COMPOSE_DIR}/${COMPOSE_FILE} up -d
ExecStop=/usr/bin/docker compose -f ${COMPOSE_DIR}/${COMPOSE_FILE} down
TimeoutStartSec=0
User=${RUN_AS_USER}
Group=docker

[Install]
WantedBy=multi-user.target
EOF

echo "wrote $UNIT_PATH"
echo
echo "next:"
echo "  systemctl daemon-reload"
echo "  systemctl enable --now ${SERVICE_NAME}.service"
