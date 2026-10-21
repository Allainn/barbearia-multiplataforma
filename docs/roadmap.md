# Roadmap até a apresentação (28/10)

Repositório: <https://github.com/Allainn/barbearia-multiplataforma>

Só entra o que o [enunciado](https://github.com/Allainn/barbearia-multiplataforma/blob/main/docs/enunciado.md) exige. Cada pessoa tem uma tarefa que roda sozinha. O único ponto de encontro é o contrato abaixo, que já está fixo, e a integração no domingo.

## Como trabalhar

- Sem issues. Cada um trabalha na branch `feat/<sua-parte>` e abre PR quando a sua parte roda.
- O ADR da sua parte é preenchido no mesmo PR do código. Status *Aceito*, e a decisão descreve o que foi implementado.
- Cada serviço é uma cópia renomeada de um serviço do PizzaExpress. Mantenha o OpenTelemetry que já vem nele.
- Para testar sem esperar ninguém, suba a infra do PizzaExpress (`pizzaexpress-ambiente/infrastructure/docker-compose.yml`). Ela já tem Postgres, Kafka, Kafka UI, Keycloak e Grafana. Quem consome evento publica mensagens de teste à mão no Kafka UI (<http://localhost:8090>).
- O contrato só muda com aviso no grupo.

## Fora do escopo

Front-end, lembretes, Outbox, reserva serializada pelo Kafka (opção D do ADR-0007), Argo CD e Minikube, validação do JWT dentro dos serviços, 403 entre barbearias, PKCE, remarcação, expediente configurável e C4 nível 3. O trace propagado pelo Kafka não é tarefa de ninguém, mas já vem pronto no código copiado do PizzaExpress (producer do `order-service-java` e consumers Python) e pode ficar.

## Contrato

### Containers

| Container | Linguagem | Porta | Copiar de (PizzaExpress) |
|---|---|---|---|
| bff-gateway | Java · Spring Boot | 8010 | `services/bff-gateway-java` |
| barbearia-service | Python · FastAPI | 8001 | `services/catalog-service` |
| agendamento-service | Java · Spring Boot | 8012 | `services/order-service-java` |
| disponibilidade-service | Python · FastAPI | 8003 | `services/delivery-service` |
| notificacao-service | Python · FastAPI | 8004 | `services/notification-service` |

Infra nas portas do PizzaExpress: Keycloak 8080, Kafka 9092, Kafka UI 8090, Postgres 5432, Grafana 3333.

Banco: um PostgreSQL, um schema por serviço (`barbearia`, `agendamento`, `disponibilidade`, `notificacao`). Os schemas e os usuários vêm do SQL do contrato ([tarefas.md](tarefas.md#banco)), e cada serviço cria as próprias tabelas ao subir.

### Rotas

O BFF valida o token. Os serviços confiam no BFF e não validam nada. O BFF repassa o `sub` do token no header `X-User-ID`.

| Rota | Serviço | Quem pode | Resposta |
|---|---|---|---|
| `GET /barbearias`, `GET /barbearias/{id}/profissionais`, `GET /barbearias/{id}/servicos` | barbearia | qualquer usuário logado | 200 |
| `POST /barbearias`, `POST /barbearias/{id}/profissionais`, `POST /barbearias/{id}/servicos` | barbearia | `gestor` | 201 |
| `POST /agendamentos` | agendamento | `cliente` | 201, ou 409 se o horário já estiver ocupado |
| `DELETE /agendamentos/{id}` | agendamento | `cliente` | 204 |
| `GET /disponibilidade?profissional_id=...&data=2026-10-28` | disponibilidade | qualquer usuário logado | 200, lista de horários livres |

Sem token ou com token inválido, o BFF responde 401. Com a role errada, 403.

Corpo do `POST /agendamentos`:

```json
{
  "barbearia_id": "11111111-1111-1111-1111-111111111111",
  "profissional_id": "22222222-2222-2222-2222-222222222222",
  "servico_id": "33333333-3333-3333-3333-333333333333",
  "inicio": "2026-10-28T18:00:00-03:00",
  "fim": "2026-10-28T18:30:00-03:00"
}
```

### Eventos no Kafka

Tópicos `agendamento.criado` e `agendamento.cancelado`, com chave `profissional_id`. Quem publica é o agendamento-service. Quem consome são o notificacao-service (group `notificacao-service`) e o disponibilidade-service (group `disponibilidade-service`).

```json
{
  "evento_id": "b6f1c0de-0000-4000-8000-000000000001",
  "tipo": "agendamento.criado",
  "versao": 1,
  "ocorrido_em": "2026-10-28T20:59:12Z",
  "barbearia_id": "11111111-1111-1111-1111-111111111111",
  "payload": {
    "agendamento_id": "44444444-4444-4444-4444-444444444444",
    "profissional_id": "22222222-2222-2222-2222-222222222222",
    "cliente_id": "id-do-usuario-no-keycloak",
    "inicio": "2026-10-28T18:00:00-03:00",
    "fim": "2026-10-28T18:30:00-03:00"
  }
}
```

### Keycloak

Realm `barbearia`, client `bff-gateway`, roles `cliente` e `gestor`, usuários de teste `cliente1`, `cliente2` e `gestor1`. As senhas estão em [tarefas.md](tarefas.md#keycloak).

### Dados fixos

Barbearia `1111...`, profissional `2222...` e serviço `3333...` (corte, 30 min), com os IDs completos do exemplo acima. O barbearia-service cria esses registros ao subir. O resto do sistema usa os mesmos IDs sem consultar o barbearia-service.

## Quem faz o quê

O passo a passo de cada parte, com as variáveis de ambiente, as tabelas e os testes de aceite, está em [tarefas.md](tarefas.md). Esse arquivo foi escrito para ser entregue à IA de cada pessoa.

### Allainn: C4, slides e revisão

- C4 níveis 1 e 2 finais, com só o que está neste roadmap, exportados para os slides. Atualizar o Miro e o Mermaid em [docs/arquitetura](https://github.com/Allainn/barbearia-multiplataforma/blob/main/docs/arquitetura/README.md).
- Slides: problema e volume de uso, C4, um slide por decisão com o porquê, trade-offs.
- ADRs 0001 a 0005.
- Revisar e aprovar os PRs no mesmo dia. A `main` exige a aprovação dele.

### João: infra, CI/CD e Grafana

- `infra/docker-compose.yml` a partir do PizzaExpress, com a infra e os 5 serviços (build de `services/<nome>`). Os dois tópicos são criados ao subir.
- GitHub Actions: build e push da imagem no GHCR para o barbearia-service, o mais fácil de mudar ao vivo. `scripts/deploy.sh` faz `docker compose pull` e `up -d` desse serviço.
- Dashboard no Grafana com a latência por endpoint, incluindo `GET /barbearias` e `POST /agendamentos`.
- ADRs 0011 e 0013.

### Evandro: Keycloak e BFF

- Seed do Keycloak conforme o contrato, adaptado de `services/bff-gateway/scripts/keycloak_seed.py` do PizzaExpress.
- bff-gateway: valida o JWT, aplica a tabela de rotas (401 e 403), repassa `X-User-ID` e encaminha para os serviços.
- ADR-0009.

### Pedro: agendamento-service

- Tabela `agendamento` com a constraint de exclusão: `EXCLUDE USING gist (profissional_id WITH =, tstzrange(inicio, fim) WITH &&) WHERE (status = 'CONFIRMADO')`. Exige `CREATE EXTENSION btree_gist`.
- `POST` grava e responde 201. Se a constraint for violada, 409. `DELETE` muda o status para `CANCELADO` e responde 204.
- Publica `agendamento.criado` e `agendamento.cancelado` logo depois do commit.
- `scripts/disputa.sh`: duas reservas iguais em paralelo, uma recebe 201 e a outra 409.
- ADRs 0007 (lock), 0010 (arquitetura interna) e 0012 (Outbox, como *Rejeitado* por prazo).

### Daniel: notificacao-service

- Consome os dois tópicos, grava o envio na tabela `notificacao.envio` e escreve no log "mensagem enviada para <cliente_id>" (o provedor é simulado).
- Ignora um `evento_id` que já processou.
- ADR-0006.

### Gabriel: disponibilidade-service (CQRS)

- Consome os dois tópicos e mantém a tabela `disponibilidade.horario_ocupado`. Criado insere, cancelado remove.
- `GET /disponibilidade` devolve a grade fixa das 09:00 às 18:00, em blocos de 30 min, menos os horários ocupados.
- ADR-0008.

### Guilherme: barbearia-service e roteiro da demo

- Cadastro de barbearias, profissionais e serviços, com os dados fixos criados ao subir.
- `scripts/demo.sh` com todas as chamadas da apresentação, escrito a partir do contrato: obter token, 401, 403, consulta, reserva, disputa, cancelamento.

Daniel, Gabriel e Guilherme não escolheram parte na Q22. As três partes são Python e têm o mesmo tamanho, então dá para trocar entre si.

## Datas

| Até | O quê |
|---|---|
| Sex 23/10 | Cada parte rodando sozinha contra a infra do PizzaExpress |
| Sáb 24/10 | PRs abertos. O `infra/` do João sobe tudo junto |
| Dom 25/10 | Integração: `scripts/demo.sh` roda do começo ao fim. O que não rodar sai dos slides |
| Seg 26/10 | Pipeline e Grafana funcionando, slides e ADRs prontos, código congelado |
| Ter 27/10 | Ensaio de 20 min e gravação da demo como reserva |
| Qua 28/10 | Apresentação e postagem no Canvas |

## O que a demo mostra

1. Sem token: 401. Cliente cadastrando serviço: 403.
2. Cliente consulta os horários livres.
3. Duas reservas no mesmo horário ao mesmo tempo: 201 para uma, 409 para a outra.
4. O evento aparece no Kafka UI, a notificação aparece no log e o horário some da consulta.
5. Uma mudança no barbearia-service passa pelo pipeline, a nova versão sobe, a chamada a `GET /barbearias` mostra a mudança e a latência aparece no Grafana.
