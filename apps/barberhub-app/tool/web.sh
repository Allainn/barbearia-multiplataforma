#!/usr/bin/env bash
# Sobe o app no navegador, para testar sem emulador Android. Só para desenvolvimento.
#
#   bash apps/barberhub-app/tool/web.sh          # http://localhost:5173
#   bash apps/barberhub-app/tool/web.sh 8088     # outra porta
#
# Precisa do back-end no ar (scripts/up.sh), do Flutter e do python3. O build web aponta o
# BFF e o Keycloak para este mesmo endereço, e o tool/web_proxy.py repassa as chamadas:
# é o que contorna a falta de CORS no BFF, sem mudar nada no back-end.
set -euo pipefail

PORTA="${1:-5173}"
cd "$(dirname "$0")/.."

flutter build web \
  --dart-define=BFF_URL="http://localhost:${PORTA}/bff" \
  --dart-define=KEYCLOAK_URL="http://localhost:${PORTA}/kc"

exec python3 tool/web_proxy.py build/web "${PORTA}"
