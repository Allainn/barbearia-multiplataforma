#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yml"

cd "$ROOT_DIR"

echo "==> Baixando a imagem atualizada do barbearia-service..."
docker compose -f "$COMPOSE_FILE" pull barbearia-service

echo "==> Recriando somente o barbearia-service sem build local..."
docker compose -f "$COMPOSE_FILE" up -d --no-build barbearia-service

echo "==> Deploy concluído."
docker compose -f "$COMPOSE_FILE" ps barbearia-service
