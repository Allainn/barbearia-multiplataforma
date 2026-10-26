#!/usr/bin/env bash
# Roda o seed do Keycloak (scripts/keycloak_seed.py) num container Python na
# rede do compose, sem depender de Python no host (ADR-0009).
#
# Uso, a partir da raiz do repositório:
#   ./scripts/keycloak-seed.sh
#
# Variáveis opcionais:
#   KEYCLOAK_URL             base do Keycloak vista de dentro da rede (default http://keycloak:8080)
#   KEYCLOAK_ADMIN           usuário admin do realm master (default admin)
#   KEYCLOAK_ADMIN_PASSWORD  senha do admin (default admin)
#   KEYCLOAK_NETWORK         rede Docker do compose (default observability)
#
# O seed só usa a biblioteca padrão do Python, então o container não precisa de
# acesso à internet nem de `pip install`. O próprio script espera o Keycloak
# responder antes de começar.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
KEYCLOAK_ADMIN="${KEYCLOAK_ADMIN:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin}"
KEYCLOAK_NETWORK="${KEYCLOAK_NETWORK:-observability}"
PYTHON_IMAGE="python:3.12-slim"

echo "==> Seed do Keycloak em $KEYCLOAK_URL (rede $KEYCLOAK_NETWORK)"
docker run --rm \
  --network "$KEYCLOAK_NETWORK" \
  -v "$ROOT_DIR/scripts:/s:ro" \
  -e KEYCLOAK_URL="$KEYCLOAK_URL" \
  -e KEYCLOAK_ADMIN="$KEYCLOAK_ADMIN" \
  -e KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD" \
  "$PYTHON_IMAGE" python /s/keycloak_seed.py
