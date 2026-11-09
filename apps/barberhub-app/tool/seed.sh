#!/usr/bin/env bash
# Popula o back-end com barbearias, profissionais e serviços para o app ter o que listar,
# buscar e filtrar. Usa só as rotas do contrato (POST do gestor pelo BFF): não mexe no banco.
#
# Uso, com o back-end no ar (bash scripts/up.sh na raiz do monorepo):
#   bash apps/barberhub-app/tool/seed.sh
#
# Pode rodar de novo: barbearia que já existe (mesmo nome) é pulada.
# Os nomes são fictícios; ruas e bairros são de Belo Horizonte. O endereço segue o
# formato "Rua, número - Bairro", de onde o app tira o bairro para o filtro.
#
# Variáveis opcionais:
#   BFF_URL       (default http://localhost:8010)
#   KEYCLOAK_URL  (default http://localhost:8080)
set -euo pipefail

BFF_URL="${BFF_URL:-http://localhost:8010}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8080}"

for comando in curl jq; do
  command -v "$comando" >/dev/null || { echo "Falta o comando '$comando'."; exit 1; }
done

# Client público do app: sem secret. O gestor1 é quem pode cadastrar.
TOKEN="$(curl -sS -X POST "$KEYCLOAK_URL/realms/barbearia/protocol/openid-connect/token" \
  -d grant_type=password -d client_id=barberhub-app \
  -d username=gestor1 -d password=gestor123 | jq -r '.access_token // empty')"
if [ -z "$TOKEN" ]; then
  echo "Não consegui o token do gestor1. O Keycloak está no ar e com o seed aplicado"
  echo "(bash scripts/keycloak-seed.sh)?"
  exit 1
fi

bff() { # bff MÉTODO CAMINHO [CORPO_JSON]
  local metodo="$1" caminho="$2" corpo="${3:-}"
  local args=(-sS --fail-with-body -X "$metodo" "$BFF_URL$caminho" -H "Authorization: Bearer $TOKEN")
  if [ -n "$corpo" ]; then
    args+=(-H 'Content-Type: application/json' -d "$corpo")
  fi
  curl "${args[@]}"
}

EXISTENTES="$(bff GET /barbearias | jq -r '.[].nome')"

# nome|endereço|profissionais separados por ;|serviços "nome:duração:preço" separados por ;
BARBEARIAS=(
  "Navalha de Ouro|Av. Getúlio Vargas, 1420 - Savassi|Rafael;Bruno;Tiago|Corte:30:55.00;Barba:30:40.00;Corte e barba:60:85.00;Pigmentação:60:120.00"
  "Savassi Clássica|Rua Pernambuco, 1000 - Savassi|Marcelo;Diego|Corte:30:50.00;Barba:30:38.00;Corte e barba:60:80.00"
  "Dom Bigode|Rua Curitiba, 2202 - Lourdes|Henrique;Lucas;André|Corte:30:60.00;Barba com toalha quente:30:45.00;Corte e barba:60:95.00"
  "Tesoura Central|Rua dos Carijós, 244 - Centro|Seu Antônio;Wesley|Corte:30:35.00;Barba:30:25.00;Corte infantil:30:30.00"
  "Barbearia do Mercado|Av. Augusto de Lima, 744 - Centro|Jorge;Fábio|Corte:30:30.00;Barba:30:22.00;Corte e barba:60:48.00"
  "Barba & Brasa|Av. Fleming, 394 - Pampulha|Caio;Mateus|Corte:30:45.00;Barba:30:35.00;Corte e barba:60:70.00;Hidratação:30:40.00"
  "Corte Mineiro|Rua Pium-í, 611 - Sion|Gustavo;Renato|Corte:30:50.00;Barba:30:35.00;Sobrancelha:30:20.00"
  "Velha Guarda|Av. Afonso Pena, 3111 - Funcionários|Seu Elias;Paulo;Vítor|Corte na tesoura:60:70.00;Corte:30:48.00;Barba:30:36.00"
  "Santa Tereza Barbearia|Rua Mármore, 320 - Santa Tereza|Léo;Samuel|Corte:30:40.00;Barba:30:30.00;Corte e barba:60:65.00"
  "Padre Eustáquio Barber Club|Rua Padre Eustáquio, 2100 - Padre Eustáquio|Igor;Davi|Corte:30:38.00;Barba:30:28.00;Corte e barba:60:60.00"
)

criadas=0
for linha in "${BARBEARIAS[@]}"; do
  IFS='|' read -r nome endereco profissionais servicos <<<"$linha"
  if grep -Fxq "$nome" <<<"$EXISTENTES"; then
    echo "  [ok    ] $nome"
    continue
  fi
  id="$(bff POST /barbearias "$(jq -nc --arg n "$nome" --arg e "$endereco" '{nome:$n, endereco:$e}')" | jq -r .id)"
  IFS=';' read -ra lista <<<"$profissionais"
  for profissional in "${lista[@]}"; do
    bff POST "/barbearias/$id/profissionais" "$(jq -nc --arg n "$profissional" '{nome:$n}')" >/dev/null
  done
  IFS=';' read -ra lista <<<"$servicos"
  for servico in "${lista[@]}"; do
    IFS=':' read -r s_nome s_duracao s_preco <<<"$servico"
    bff POST "/barbearias/$id/servicos" \
      "$(jq -nc --arg n "$s_nome" --argjson d "$s_duracao" --arg p "$s_preco" '{nome:$n, duracao_min:$d, preco:$p}')" >/dev/null
  done
  echo "  [criada] $nome"
  criadas=$((criadas + 1))
done

echo "Seed do app concluído: $criadas barbearia(s) nova(s)."
