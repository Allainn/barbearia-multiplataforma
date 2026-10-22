#!/bin/sh
# Provisiona no Kibana o Data View dos logs do PizzaExpress.
# Idempotente: se já existir (id fixo), o Kibana responde 400 e seguimos.
set -e
KIBANA=http://kibana:5601

echo "[kibana-setup] criando data view pizzaexpress-logs*"
curl -s -X POST "$KIBANA/api/data_views/data_view" \
  -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
  -d '{
        "data_view": {
          "id": "pizzaexpress-logs",
          "title": "pizzaexpress-logs*",
          "name": "PizzaExpress — logs (OTel)",
          "timeFieldName": "@timestamp"
        },
        "override": true
      }' >/dev/null

echo "[kibana-setup] definindo como data view padrão"
curl -s -X POST "$KIBANA/api/data_views/default" \
  -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
  -d '{"data_view_id":"pizzaexpress-logs","force":true}' >/dev/null

echo "[kibana-setup] ok"
