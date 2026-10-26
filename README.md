# Barbearia Multiplataforma

Trabalho final da disciplina **Arquitetura de Software Multiplataforma** (pós em Arquitetura de Software Distribuído, PUC Minas), prof. Messias Barbosa Bittencourt.

> **Situação (24/10/2026):** integração dos serviços em 25/10. O escopo, o contrato e a parte de cada pessoa estão no [roadmap](docs/roadmap.md) e nas [tarefas](docs/tarefas.md). Apresentação em **28/10/2026**. Para subir o sistema, veja [Como rodar](#como-rodar).

## O sistema

Plataforma **multi-tenant** de agendamento para barbearias (nome votado na Q02: **BarberHub**): muitas barbearias usam a mesma plataforma, e os clientes consultam horários livres e agendam. O enquadramento com escala e a volumetria assumida estão no [ADR-0003](docs/adr/0003-enquadramento-plataforma-multi-tenant.md).

Na demo: o cliente obtém o token no Keycloak e chama o BFF, que valida o token (401/403) e encaminha para os serviços. O agendamento grava a reserva, e uma constraint do PostgreSQL impede dois agendamentos sobrepostos para o mesmo profissional (409 para o segundo). O evento vai para o Kafka e é consumido pela notificação e pela disponibilidade (lado de leitura do CQRS).

## Como rodar

### Pré-requisitos

- Docker com Docker Compose v2 e pelo menos **8 GB de RAM** liberados para o Docker.
- **No Windows:** WSL2 com o Docker Desktop (integração com o WSL ligada). Clone o repositório **dentro do WSL** (ex.: `~/barbearia-multiplataforma`), não em `/mnt/c`.
- `bash`, `curl` e `jq`. Os scripts da demo usam o `date` do GNU, então rodam no Linux e no WSL.

### Subir e derrubar

```bash
git clone https://github.com/Allainn/barbearia-multiplataforma.git
cd barbearia-multiplataforma
bash scripts/up.sh
```

O `up.sh` constrói as imagens, sobe os containers, espera o Keycloak e aplica o seed (realm `barbearia`, client, roles e usuários de teste). A primeira subida leva alguns minutos por causa do download das imagens e do build do Java. Para ver o estado de cada container:

```bash
docker compose -f infra/docker-compose.yml ps
```

Para derrubar, `bash scripts/down.sh`. Os dados ficam em `infra/data/`; para começar do zero, apague essa pasta (pode precisar de `sudo`).

### Endereços

| O quê | Endereço | Acesso |
|---|---|---|
| **bff-gateway**: a entrada da API | <http://localhost:8010> | token do Keycloak (abaixo) |
| Keycloak | <http://localhost:8080> | `admin` / `admin` |
| Grafana | <http://localhost:3333> | sem login |
| Kafka UI | <http://localhost:8090> | sem login |
| PostgreSQL | `localhost:5432`, banco `barbearia` | `barbearia` / `barbearia` |

Os serviços de domínio não publicam porta no host: só o BFF é alcançável de fora, e os serviços confiam no `X-User-ID` que ele envia ([ADR-0015](docs/adr/0015-onde-autenticar-e-autorizar.md)). Para depurar um serviço direto, use `docker exec` ou publique a porta só na sua máquina com um override do Compose.

### Usuários de teste e token

| Usuário | Senha | Role |
|---|---|---|
| `cliente1` | `cliente123` | `cliente` |
| `cliente2` | `cliente123` | `cliente` |
| `gestor1` | `gestor123` | `gestor` |

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/realms/barbearia/protocol/openid-connect/token \
  -d grant_type=password -d client_id=bff-gateway -d client_secret=bff-secret \
  -d username=cliente1 -d password=cliente123 | jq -r .access_token)

curl -s -H "Authorization: Bearer $TOKEN" http://localhost:8010/barbearias | jq
```

Como a demo é feita com curl, o token vem do *password grant*. Com um front-end, o fluxo seria Authorization Code com PKCE.

### Rotas da API (pelo BFF, porta 8010)

| Rota | Role exigida | Resposta |
|---|---|---|
| `GET /barbearias` | qualquer usuário logado | 200, lista de barbearias |
| `POST /barbearias` | `gestor` | 201 |
| `GET /barbearias/{id}/profissionais` | qualquer usuário logado | 200 ou 404 |
| `POST /barbearias/{id}/profissionais` | `gestor` | 201 ou 404 |
| `GET /barbearias/{id}/servicos` | qualquer usuário logado | 200 ou 404 |
| `POST /barbearias/{id}/servicos` | `gestor` | 201 ou 404 |
| `GET /disponibilidade?profissional_id=...&data=AAAA-MM-DD` | qualquer usuário logado | 200, horários livres do dia |
| `POST /agendamentos` | `cliente` | 201, ou **409** se o horário já estiver ocupado |
| `DELETE /agendamentos/{id}` | `cliente` | 204 ou 404 |

Sem token, ou com token inválido, o BFF responde **401**; com a role errada, **403**; com o serviço fora do ar, 503. Os corpos de entrada e saída estão no [contrato](docs/tarefas.md#rotas); a especificação OpenAPI completa, com exemplos, está em [`services/bff-gateway/openapi.yaml`](services/bff-gateway/openapi.yaml). O barbearia-service cria ao subir a barbearia `11111111-1111-1111-1111-111111111111`, o profissional `22222222-2222-2222-2222-222222222222` e o serviço `33333333-3333-3333-3333-333333333333`, que os exemplos usam.

Exemplo de reserva:

```bash
curl -s -X POST http://localhost:8010/agendamentos \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"barbearia_id":"11111111-1111-1111-1111-111111111111",
       "profissional_id":"22222222-2222-2222-2222-222222222222",
       "servico_id":"33333333-3333-3333-3333-333333333333",
       "inicio":"2026-10-29T10:00:00-03:00","fim":"2026-10-29T10:30:00-03:00"}' | jq
```

### Roteiro da demo

```bash
bash scripts/demo.sh      # roteiro da apresentação, tudo pelo BFF; Enter avança cada passo
bash scripts/disputa.sh   # só a disputa: duas reservas iguais ao mesmo tempo, 201 e 409
```

O `demo.sh` mostra:
1. o 401 sem token e o 403 de um cliente cadastrando serviço;
2. a consulta dos horários livres;
3. a disputa pelo mesmo horário, com 201 para uma reserva e 409 para a outra;
4. o evento no Kafka UI e a notificação no log;
5. o horário sumindo da consulta;
6. o cancelamento, com 204, e o horário voltando.

### CI/CD

1. Uma mudança em `services/barbearia-service/` enviada para a `main` ou para uma branch `demo/**` dispara o workflow [`barbearia-service.yml`](.github/workflows/barbearia-service.yml).
2. O workflow roda o smoke test, constrói a imagem e publica no GHCR (`ghcr.io/allainn/barbearia-multiplataforma/barbearia-service`) com as tags `latest` e o SHA do commit.
3. `bash scripts/deploy.sh` baixa a imagem nova e recria só o barbearia-service, sem build local.
4. No Grafana, o dashboard **Traces — Requests e Percurso Distribuído** mostra qual versão (commit) atendeu cada request.

Decisão e alternativas no [ADR-0013](docs/adr/0013-entrega-continua-e-observabilidade.md).

### Observabilidade

Os serviços mandam logs, métricas e traces por OpenTelemetry para o Collector, que distribui para o Loki, o Prometheus e o Tempo. Os dashboards já vêm carregados no Grafana:

| Dashboard | O que mostra |
|---|---|
| Latência — P90 / P95 / P99 | Latência por serviço e por rota |
| Traces — Requests e Percurso Distribuído | O caminho de cada request entre os serviços, inclusive pelo Kafka; versão em produção |
| Kafka — Consumer Lag e Throughput | Mensagens produzidas e consumidas; atraso de cada consumer group |
| Banco de Dados — Query Times | Consultas ao PostgreSQL dentro dos traces |
| Disponibilidade — Healthcheck | Se cada serviço está no ar; taxa de erros 4xx e 5xx; logs de erro |

### Problemas comuns

- **Algum container reiniciando:** `docker compose -f infra/docker-compose.yml logs <container>`.
- **`permission denied` nos logs do Grafana, Loki, Kafka ou Keycloak:** as pastas de `infra/data/` foram criadas sem permissão de escrita. Rode `sudo chmod -R 777 infra/data` e `bash scripts/up.sh` de novo.
- **Porta em uso:** o Compose publica as portas 3100, 3200, 3333, 4317 a 4320, 5432, 8010, 8080, 8090, 8889, 9000, 9090, 9092, 9308 e 29092. Pare o que estiver usando a porta, por exemplo um PostgreSQL local na 5432.
- **`demo.sh` não obtém os tokens:** o seed do Keycloak não rodou. Rode `bash scripts/up.sh` de novo; o seed pode ser repetido sem problema.

## Onde está cada coisa

| O quê | Onde |
|---|---|
| Plano até a apresentação: escopo, contrato e datas | [docs/roadmap.md](docs/roadmap.md) |
| Passo a passo de cada pessoa (para entregar à IA de cada um) | [docs/tarefas.md](docs/tarefas.md) |
| Regras do trabalho e checklist do professor | [docs/enunciado.md](docs/enunciado.md) |
| Decisões arquiteturais (ADRs) | [docs/adr/](docs/adr/README.md) |
| C4 (níveis 1 e 2) | [Board no Miro](https://miro.com/app/board/uXjVEdd_Nsc=/) + espelho em Mermaid em [docs/arquitetura](docs/arquitetura/README.md) |
| Questões votadas de 07 a 09/10 (histórico) | [docs/questoes-abertas.md](docs/questoes-abertas.md) e issues #1 a #24 |
| Como contribuir (branches, PR, aprovação) | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Contexto para o Claude Code | [CLAUDE.md](CLAUDE.md) |
| Código dos serviços | `services/<container>/` |
| Infraestrutura (Docker Compose, Grafana) | `infra/` |

## Grupo

| Integrante | Parte |
|---|---|
| Allainn Christiam Jacinto Tavares | C4, slides e revisão dos PRs |
| João Almeida Barbosa Júnior | Infra, CI/CD e Grafana |
| Evandro Vieira de Carvalho Júnior | Keycloak e bff-gateway |
| Pedro Assis Corrêa | agendamento-service |
| Daniel da Silveira Moreira | notificacao-service |
| Gabriel Santiago Silva | disponibilidade-service |
| Guilherme Nunes Faria | barbearia-service e roteiro da demo |

## Cronograma

| Até | O quê |
|---|---|
| Sex 23/10 | Cada parte rodando sozinha contra a infra do PizzaExpress |
| Sáb 24/10 | PRs abertos; o `infra/` sobe tudo junto |
| Dom 25/10 | Integração: `scripts/demo.sh` do começo ao fim |
| Seg 26/10 | Pipeline e Grafana funcionando, slides e ADRs prontos, código congelado |
| Ter 27/10 | Ensaio de 20 min e gravação da demo como reserva |
| Qua 28/10 | Apresentação e postagem no Canvas |
