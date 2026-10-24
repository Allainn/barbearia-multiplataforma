#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yml"

cd "$ROOT_DIR"

PERFIS=()
if [[ -d "$ROOT_DIR/services/bff-gateway" ]]; then
  PERFIS=(--profile bff)
fi

echo "==> Derrubando a plataforma e preservando os dados..."
docker compose -f "$COMPOSE_FILE" "${PERFIS[@]}" down

echo "==> Ambiente derrubado. Volumes e dados locais foram preservados."
