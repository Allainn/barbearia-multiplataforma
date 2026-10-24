#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/infra/docker-compose.yml"

cd "$ROOT_DIR"

echo "==> Subindo a plataforma com build das imagens..."
docker compose -f "$COMPOSE_FILE" up --build -d

if [[ -f "$ROOT_DIR/scripts/keycloak-seed.sh" ]]; then
  echo "==> Aguardando o Keycloak..."
  for tentativa in $(seq 1 40); do
    if curl -sf http://localhost:8080/realms/master >/dev/null; then
      break
    fi
    if [[ "$tentativa" -eq 40 ]]; then
      echo "Keycloak não respondeu em 2 minutos; veja: docker compose -f \"$COMPOSE_FILE\" logs keycloak" >&2
      exit 1
    fi
    sleep 3
  done

  echo "==> Executando o seed do Keycloak..."
  bash "$ROOT_DIR/scripts/keycloak-seed.sh"
else
  echo "==> Seed do Keycloak não encontrado; seguindo sem seed."
fi

echo "==> Ambiente iniciado."
docker compose -f "$COMPOSE_FILE" ps
