#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yml"

cd "$ROOT_DIR"

echo "==> Subindo a plataforma com build das imagens..."
docker compose -f "$COMPOSE_FILE" up --build -d

if [[ -f "$ROOT_DIR/scripts/keycloak-seed.sh" ]]; then
  echo "==> Executando o seed do Keycloak..."
  "$ROOT_DIR/scripts/keycloak-seed.sh"
else
  echo "==> Seed do Keycloak não encontrado; seguindo sem seed."
fi

echo "==> Ambiente iniciado."
docker compose -f "$COMPOSE_FILE" ps
