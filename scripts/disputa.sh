#!/usr/bin/env bash
# Disputa pelo mesmo horário (ADR-0007): duas reservas iguais ao mesmo tempo.
# Esperado: uma recebe 201 e a outra 409, porque a constraint de exclusão do
# PostgreSQL recusa o segundo agendamento sobreposto do mesmo profissional.
#
# Uso:
#   scripts/disputa.sh                      # direto no agendamento-service (porta 8012)
#   TOKEN=... scripts/disputa.sh            # pelo BFF (porta 8010), mesmo token nas duas
#   TOKEN=... TOKEN2=... scripts/disputa.sh # pelo BFF, um cliente em cada reserva
#
# Variáveis: BASE_URL, TOKEN, TOKEN2, PROFISSIONAL_ID, DIA (AAAA-MM-DD, padrão amanhã).
set -euo pipefail

BARBEARIA_ID="11111111-1111-1111-1111-111111111111"
PROFISSIONAL_ID="${PROFISSIONAL_ID:-22222222-2222-2222-2222-222222222222}"
SERVICO_ID="33333333-3333-3333-3333-333333333333"

if [[ -n "${TOKEN:-}" ]]; then
  BASE_URL="${BASE_URL:-http://localhost:8010}"
else
  BASE_URL="${BASE_URL:-http://localhost:8012}"
fi

DIA="${DIA:-$(date -d tomorrow +%F)}"
hora() { printf '%02d:%02d' $(($1 / 60)) $(($1 % 60)); }

# Sorteia um bloco de 30 min entre 09:00 e 17:30 do dia, para o script poder rodar várias vezes.
sortear_horario() {
  local inicio_min=$((9 * 60 + (RANDOM % 18) * 30))
  INICIO="${DIA}T$(hora $inicio_min):00-03:00"
  FIM="${DIA}T$(hora $((inicio_min + 30))):00-03:00"
  CORPO="{\"barbearia_id\":\"$BARBEARIA_ID\",\"profissional_id\":\"$PROFISSIONAL_ID\",\"servico_id\":\"$SERVICO_ID\",\"inicio\":\"$INICIO\",\"fim\":\"$FIM\"}"
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

reservar() {
  local nome="$1" token="$2"
  local auth=()
  if [[ -n "$token" ]]; then
    auth=(-H "Authorization: Bearer $token")
  else
    auth=(-H "X-User-ID: $nome")
  fi
  curl -s -o "$TMP/$nome.body" -w '%{http_code}' -X POST "$BASE_URL/agendamentos" \
    -H 'Content-Type: application/json' "${auth[@]}" -d "$CORPO" > "$TMP/$nome.status"
}

echo "Disputa em $BASE_URL"

# Se as duas voltarem 409, o bloco sorteado já estava reservado de uma rodada anterior: sorteia outro.
for tentativa in 1 2 3 4 5 6 7 8 9 10; do
  sortear_horario
  reservar cliente-a "${TOKEN:-}" &
  reservar cliente-b "${TOKEN2:-${TOKEN:-}}" &
  wait
  [[ "$(cat "$TMP/cliente-a.status") $(cat "$TMP/cliente-b.status")" != "409 409" ]] && break
  echo "Bloco de $INICIO já ocupado, sorteando outro."
done

echo "Profissional $PROFISSIONAL_ID, de $INICIO a $FIM"
echo

for nome in cliente-a cliente-b; do
  echo "$nome: HTTP $(cat "$TMP/$nome.status")"
  cat "$TMP/$nome.body"
  echo
done

A=$(cat "$TMP/cliente-a.status")
B=$(cat "$TMP/cliente-b.status")
if [[ "$A $B" == "201 409" || "$A $B" == "409 201" ]]; then
  echo "OK: uma reserva confirmada e a outra recusada."
elif [[ "$A $B" == "409 409" ]]; then
  echo "Os blocos sorteados de $DIA já estavam todos reservados. Rode de novo com DIA=AAAA-MM-DD para outro dia."
  exit 1
else
  echo "Resultado inesperado: $A e $B (esperado: 201 e 409)."
  exit 1
fi
