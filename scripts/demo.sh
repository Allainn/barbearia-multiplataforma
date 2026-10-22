#!/usr/bin/env bash
# Roteiro da apresentacao. Tudo pelo BFF. Requer curl, jq e GNU date.
set -u

BFF="${BFF:-http://localhost:8010}"
KEYCLOAK="${KEYCLOAK:-http://localhost:8080}"
BARBEARIA_ID="11111111-1111-1111-1111-111111111111"
PROFISSIONAL_ID="22222222-2222-2222-2222-222222222222"
SERVICO_ID="33333333-3333-3333-3333-333333333333"
AMANHA="$(date -d tomorrow +%F)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

token() {
  curl -s -X POST "$KEYCLOAK/realms/barbearia/protocol/openid-connect/token" \
    -d grant_type=password -d client_id=bff-gateway -d client_secret=bff-secret \
    -d "username=$1" -d "password=$2" | jq -r .access_token
}

passo() {
  echo
  echo "=============================================================="
  echo "PASSO $1: $2"
  echo "=============================================================="
}

# chamar <titulo do comando> <arquivo de saida> <args do curl...>
# Imprime o comando, o status e o corpo formatado. Grava o status em <saida>.status.
chamar() {
  local rotulo="$1" saida="$2"
  shift 2
  echo "\$ $rotulo"
  local status
  status="$(curl -s -o "$saida.body" -w '%{http_code}' "$@")"
  echo "$status" > "$saida.status"
  echo "HTTP $status"
  jq . "$saida.body" 2>/dev/null || cat "$saida.body"
}

espera() {
  echo
  read -r -p "[Enter para continuar] " _
}

echo "Obtendo tokens de cliente1, cliente2 e gestor1..."
TOKEN_C1="$(token cliente1 cliente123)"
TOKEN_C2="$(token cliente2 cliente123)"
TOKEN_G1="$(token gestor1 gestor123)"
if [ -z "$TOKEN_C1" ] || [ "$TOKEN_C1" = "null" ] || [ "$TOKEN_G1" = "null" ]; then
  echo "Nao consegui obter os tokens. O Keycloak esta no ar e com o seed aplicado?"
  exit 1
fi

consulta() {
  curl -s -H "Authorization: Bearer $TOKEN_C1" \
    "$BFF/disponibilidade?profissional_id=$PROFISSIONAL_ID&data=$AMANHA"
}

passo 1 "Sem token: 401"
chamar "curl $BFF/barbearias" "$TMP/p1" "$BFF/barbearias"
espera

passo 2 "Cliente cadastrando servico: 403"
chamar "curl -X POST $BFF/barbearias/$BARBEARIA_ID/servicos (token cliente1)" "$TMP/p2" \
  -X POST "$BFF/barbearias/$BARBEARIA_ID/servicos" \
  -H "Authorization: Bearer $TOKEN_C1" -H "Content-Type: application/json" \
  -d '{"nome":"Barba","duracao_min":20,"preco":30.00}'
espera

passo 3 "Gestor cadastrando servico: 201"
chamar "curl -X POST $BFF/barbearias/$BARBEARIA_ID/servicos (token gestor1)" "$TMP/p3" \
  -X POST "$BFF/barbearias/$BARBEARIA_ID/servicos" \
  -H "Authorization: Bearer $TOKEN_G1" -H "Content-Type: application/json" \
  -d '{"nome":"Barba","duracao_min":20,"preco":30.00}'
espera

passo 4 "Cliente consulta os horarios livres de $AMANHA"
chamar "curl $BFF/disponibilidade?profissional_id=...&data=$AMANHA (token cliente1)" "$TMP/p4" \
  -H "Authorization: Bearer $TOKEN_C1" \
  "$BFF/disponibilidade?profissional_id=$PROFISSIONAL_ID&data=$AMANHA"
INICIO="$(jq -r '.horarios_livres[0].inicio // empty' "$TMP/p4.body")"
FIM="$(jq -r '.horarios_livres[0].fim // empty' "$TMP/p4.body")"
if [ -z "$INICIO" ]; then
  echo "Nao ha horario livre em $AMANHA. Abortando."
  exit 1
fi
echo "Horario escolhido para a disputa: $INICIO a $FIM"
espera

passo 5 "Disputa: cliente1 e cliente2 reservam o mesmo horario ao mesmo tempo"
CORPO="$(jq -n --arg b "$BARBEARIA_ID" --arg p "$PROFISSIONAL_ID" --arg s "$SERVICO_ID" \
  --arg i "$INICIO" --arg f "$FIM" \
  '{barbearia_id:$b, profissional_id:$p, servico_id:$s, inicio:$i, fim:$f}')"
echo "\$ POST $BFF/agendamentos (cliente1 e cliente2, em paralelo)"
echo "$CORPO" | jq .
for quem in c1 c2; do
  if [ "$quem" = "c1" ]; then T="$TOKEN_C1"; else T="$TOKEN_C2"; fi
  (
    curl -s -o "$TMP/disputa-$quem.body" -w '%{http_code}' -X POST "$BFF/agendamentos" \
      -H "Authorization: Bearer $T" -H "Content-Type: application/json" \
      -d "$CORPO" > "$TMP/disputa-$quem.status"
  ) &
done
wait
RESERVOU=""
for quem in c1 c2; do
  status="$(cat "$TMP/disputa-$quem.status")"
  echo
  echo "$quem -> HTTP $status"
  jq . "$TMP/disputa-$quem.body" 2>/dev/null || cat "$TMP/disputa-$quem.body"
  if [ "$status" = "201" ]; then RESERVOU="$quem"; fi
done
espera

passo 6 "Evento no Kafka UI e notificacao no log"
echo "Kafka UI: http://localhost:8090 -> Topics -> agendamento.criado"
echo
echo "\$ docker logs notificacao-service --tail 5"
docker logs notificacao-service --tail 5 2>&1 || echo "(container notificacao-service nao encontrado)"
espera

passo 7 "Mesma consulta do passo 4: o horario reservado sumiu"
echo "(a disponibilidade e eventualmente consistente; se ainda aparecer, repita)"
chamar "curl $BFF/disponibilidade?profissional_id=...&data=$AMANHA (token cliente1)" "$TMP/p7" \
  -H "Authorization: Bearer $TOKEN_C1" \
  "$BFF/disponibilidade?profissional_id=$PROFISSIONAL_ID&data=$AMANHA"
if jq -e --arg i "$INICIO" '.horarios_livres | map(.inicio) | index($i)' "$TMP/p7.body" >/dev/null 2>&1; then
  echo ">> $INICIO ainda aparece como livre"
else
  echo ">> $INICIO nao aparece mais"
fi
espera

passo 8 "Cancelamento: 204"
if [ -z "$RESERVOU" ]; then
  echo "Nenhuma reserva com 201 na disputa; nada para cancelar."
else
  if [ "$RESERVOU" = "c1" ]; then T="$TOKEN_C1"; else T="$TOKEN_C2"; fi
  ID="$(jq -r .id "$TMP/disputa-$RESERVOU.body")"
  chamar "curl -X DELETE $BFF/agendamentos/$ID (token de quem reservou)" "$TMP/p8" \
    -X DELETE "$BFF/agendamentos/$ID" -H "Authorization: Bearer $T"
fi
espera

passo 9 "Mesma consulta: o horario voltou"
echo "(aguarde 1 segundo para o evento chegar na disponibilidade)"
sleep 1
chamar "curl $BFF/disponibilidade?profissional_id=...&data=$AMANHA (token cliente1)" "$TMP/p9" \
  -H "Authorization: Bearer $TOKEN_C1" \
  "$BFF/disponibilidade?profissional_id=$PROFISSIONAL_ID&data=$AMANHA"
if jq -e --arg i "$INICIO" '.horarios_livres | map(.inicio) | index($i)' "$TMP/p9.body" >/dev/null 2>&1; then
  echo ">> $INICIO voltou para a lista"
else
  echo ">> $INICIO ainda nao voltou"
fi

echo
echo "Fim do roteiro."
