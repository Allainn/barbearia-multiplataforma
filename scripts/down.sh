#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yml"

cd "$ROOT_DIR"

echo "==> Derrubando a plataforma e preservando os dados..."
docker compose -f "$COMPOSE_FILE" down

echo "==> Ambiente derrubado. Volumes e dados locais foram preservados."
