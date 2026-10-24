# Tarefas por pessoa

Versão de 21/10/2026. Complementa o [roadmap](roadmap.md), que tem o resumo e as datas.

## Para a IA que está lendo este arquivo

Você vai ajudar um integrante do grupo a fazer a parte dele. Leia as seções **Contexto**, **Regras**, **Fora do escopo**, **Contrato** e **Como testar sozinho**, e depois só a seção da pessoa com quem você está trabalhando. Pergunte o nome dela se não souber.

- Faça só a parte dessa pessoa. Não crie nem altere arquivos fora da lista "Arquivos que você pode mexer" da seção dela.
- O contrato é fixo. Se algo nele for impossível de cumprir, pare e diga à pessoa para avisar o grupo antes de mudar qualquer coisa.
- Tudo o que está em "Fora do escopo" fica fora, mesmo que pareça fácil.
- Prefira copiar e adaptar o código do PizzaExpress a escrever do zero.
- A parte está pronta quando todos os itens de "Pronto quando" passarem.

## Contexto

Trabalho final da disciplina Arquitetura de Software Multiplataforma (PUC Minas). Plataforma multi-tenant de agendamento para barbearias. Apresentação de 20 minutos em 28/10/2026. O professor avalia as integrações funcionando e a justificativa das decisões. Ele não avalia regra de negócio, front-end nem qualidade fina de código.

O sistema tem 5 containers (2 em Java, 3 em Python), Keycloak, Kafka, PostgreSQL e a stack Grafana. O fluxo da demo é este: o cliente pega o token no Keycloak e chama o BFF. O BFF valida o token e encaminha para os serviços. O agendamento grava a reserva, e uma constraint do Postgres impede dois agendamentos sobrepostos para o mesmo profissional, devolvendo 409 para o segundo. Depois o agendamento publica um evento no Kafka, e a notificação e a disponibilidade consomem esse evento.

Repositório: <https://github.com/Allainn/barbearia-multiplataforma>

Código-base: pacote `pizzaexpress-ambiente.zip` do Canvas, o sistema de exemplo do professor. Neste arquivo ele aparece extraído em `~/pizzaexpress/pizzaexpress-ambiente`. No Windows, extraia e rode tudo dentro do WSL2, numa pasta em `~/`, não em `/mnt/c`. Docker precisa de pelo menos 8 GB de RAM.

## Regras

- Branch `feat/<sua-parte>` criada a partir da `main`. PR para a `main`. O merge exige 1 aprovação e a aprovação do Allainn.
- Commits no padrão Conventional Commits, em português, citando o ADR. Exemplo: `feat(agendamento): reserva com constraint de exclusão (ADR-0007)`.
- Sem issues.
- O ADR da sua parte é preenchido no mesmo PR do código. Mude o status para *Aceito*, a data para o dia do PR, reescreva a seção "Decisão" com o que foi implementado de fato e apague a seção "Perguntas para o grupo". Mantenha as opções consideradas. Não edite `docs/adr/README.md`, quem atualiza o índice é o Allainn. Os ADRs gerais (0001 a 0005) não pertencem a nenhuma parte e ficaram com o Allainn em 24/10: não mexa neles.
- Ao copiar um serviço do PizzaExpress, apague `target/`, `.ruff_cache/`, `*.egg-info/`, `__pycache__/` e a pasta de testes. Troque todo nome e texto de pizza pelo nosso domínio. O código fica com o domínio em português (`Agendamento`, `agendamento.criado`) e os termos técnicos em inglês (`Repository`, `UseCase`, `Controller`).
- Mantenha o OpenTelemetry que vem no serviço copiado. Troque o nome do serviço para o nome do container (tabela abaixo) e, onde aparecer no código, o `service.namespace` de `pizzaexpress` para `barbearia`. O dashboard do Grafana filtra pelo nome do serviço.
- Mantenha o filtro de latência artificial (`DemoLatencyFilter` no Java, `demo_latency_middleware` no Python). O header `X-Demo-Delay-Ms` serve para mostrar latência no Grafana.
- Rotas sem barra no final (`/agendamentos`, não `/agendamentos/`). O PizzaExpress usa barra no final em alguns lugares; tire.

## Fora do escopo

Front-end, lembretes, Outbox, reserva assíncrona pelo Kafka, Argo CD e Minikube, validação do JWT dentro dos serviços, 403 entre barbearias, PKCE, remarcação, expediente configurável, evento `expediente.alterado`, chamada do agendamento ao barbearia-service, DLQ, propagação de trace pelo Kafka (se já vier pronta no código copiado, pode ficar), C4 nível 3 e testes automatizados.

## Contrato

### Containers

O nome do container também é o hostname dentro da rede Docker `observability` e o `service.name` do OpenTelemetry.

| Container | Linguagem | Porta | Copiar de | Pacote / módulo |
|---|---|---|---|---|
| `bff-gateway` | Java 21 · Spring Boot 3 | 8010 | `services/bff-gateway-java` | `com.barbearia.bff` |
| `barbearia-service` | Python 3.12 · FastAPI | 8001 | `services/catalog-service` | `barbearia` |
| `agendamento-service` | Java 21 · Spring Boot 3 | 8012 | `services/order-service-java` | `com.barbearia.agendamento` |
| `disponibilidade-service` | Python 3.12 · FastAPI | 8003 | `services/delivery-service` | `disponibilidade` |
| `notificacao-service` | Python 3.12 · FastAPI | 8004 | `services/notification-service` | `notificacao` |

Infra, com os mesmos nomes e portas do PizzaExpress: `postgres` 5432, `kafka` 9092, `kafka-ui` 8090 (no host), `keycloak` 8080, `otel-collector` 4318 (dentro da rede), `grafana` 3333 (no host).

Cada serviço fica em `services/<container>/`, com o próprio `Dockerfile`.

### Variáveis de ambiente

Valem igual no teste sozinho e na infra final.

| Container | Variáveis |
|---|---|
| `bff-gateway` | `BARBEARIA_URL=http://barbearia-service:8001` · `AGENDAMENTO_URL=http://agendamento-service:8012` · `DISPONIBILIDADE_URL=http://disponibilidade-service:8003` · `KEYCLOAK_URL=http://keycloak:8080/realms/barbearia` · `KEYCLOAK_CLIENT_ID=bff-gateway` · `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` |
| `barbearia-service` | `DATABASE_URL=postgresql://barbearia_svc:barbearia_pass@postgres/barbearia?options=-csearch_path=barbearia` · `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` · `OTEL_SERVICE_NAME=barbearia-service` |
| `agendamento-service` | `SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/barbearia?currentSchema=agendamento` · `SPRING_DATASOURCE_USERNAME=agendamento_svc` · `SPRING_DATASOURCE_PASSWORD=agendamento_pass` · `KAFKA_BOOTSTRAP_SERVERS=kafka:9092` · `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` |
| `disponibilidade-service` | `DATABASE_URL=postgresql://disponibilidade_svc:disponibilidade_pass@postgres/barbearia?options=-csearch_path=disponibilidade` · `KAFKA_BOOTSTRAP_SERVERS=kafka:9092` · `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` · `OTEL_SERVICE_NAME=disponibilidade-service` |
| `notificacao-service` | `DATABASE_URL=postgresql://notificacao_svc:notificacao_pass@postgres/barbearia?options=-csearch_path=notificacao` · `KAFKA_BOOTSTRAP_SERVERS=kafka:9092` · `OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318` · `OTEL_SERVICE_NAME=notificacao-service` |

### Banco

Um PostgreSQL 16, banco `barbearia`, um schema e um usuário por serviço. Este SQL cria tudo, e cada serviço cria as próprias tabelas ao subir:

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS barbearia;
CREATE SCHEMA IF NOT EXISTS agendamento;
CREATE SCHEMA IF NOT EXISTS disponibilidade;
CREATE SCHEMA IF NOT EXISTS notificacao;

CREATE USER barbearia_svc WITH PASSWORD 'barbearia_pass';
CREATE USER agendamento_svc WITH PASSWORD 'agendamento_pass';
CREATE USER disponibilidade_svc WITH PASSWORD 'disponibilidade_pass';
CREATE USER notificacao_svc WITH PASSWORD 'notificacao_pass';

GRANT USAGE, CREATE ON SCHEMA barbearia TO barbearia_svc;
GRANT USAGE, CREATE ON SCHEMA agendamento TO agendamento_svc;
GRANT USAGE, CREATE ON SCHEMA disponibilidade TO disponibilidade_svc;
GRANT USAGE, CREATE ON SCHEMA notificacao TO notificacao_svc;
```

### Rotas

Os clientes externos só falam com o BFF (porta 8010). O BFF valida o token e chama o serviço com a mesma rota, o mesmo corpo e a mesma query string, mais o header `X-User-ID` com o `sub` do token. Os serviços não validam token. O status e o corpo da resposta do serviço voltam iguais para quem chamou.

| Rota | Serviço | Role exigida no BFF | Corpo de entrada | Resposta |
|---|---|---|---|---|
| `GET /barbearias` | barbearia | qualquer usuário logado | | 200, lista de barbearias |
| `POST /barbearias` | barbearia | `gestor` | `{"nome", "endereco"}` | 201, a barbearia criada |
| `GET /barbearias/{id}/profissionais` | barbearia | qualquer usuário logado | | 200 ou 404 |
| `POST /barbearias/{id}/profissionais` | barbearia | `gestor` | `{"nome"}` | 201 ou 404 |
| `GET /barbearias/{id}/servicos` | barbearia | qualquer usuário logado | | 200 ou 404 |
| `POST /barbearias/{id}/servicos` | barbearia | `gestor` | `{"nome", "duracao_min", "preco"}` | 201 ou 404 |
| `POST /agendamentos` | agendamento | `cliente` | ver abaixo | 201, ou 409 se o horário estiver ocupado |
| `DELETE /agendamentos/{id}` | agendamento | `cliente` | | 204 ou 404 |
| `GET /disponibilidade?profissional_id=...&data=AAAA-MM-DD` | disponibilidade | qualquer usuário logado | | 200, ver abaixo |

Sem token, ou com token inválido ou expirado, o BFF responde 401. Com a role errada, 403. Serviço fora do ar, 503.

Todo objeto devolvido tem `id` (UUID). Erro sempre no formato `{"detail": "mensagem"}`.

`POST /agendamentos`, entrada:

```json
{
  "barbearia_id": "11111111-1111-1111-1111-111111111111",
  "profissional_id": "22222222-2222-2222-2222-222222222222",
  "servico_id": "33333333-3333-3333-3333-333333333333",
  "inicio": "2026-10-28T18:00:00-03:00",
  "fim": "2026-10-28T18:30:00-03:00"
}
```

`POST /agendamentos`, resposta 201:

```json
{
  "id": "44444444-4444-4444-4444-444444444444",
  "barbearia_id": "11111111-1111-1111-1111-111111111111",
  "profissional_id": "22222222-2222-2222-2222-222222222222",
  "servico_id": "33333333-3333-3333-3333-333333333333",
  "cliente_id": "valor do X-User-ID",
  "inicio": "2026-10-28T18:00:00-03:00",
  "fim": "2026-10-28T18:30:00-03:00",
  "status": "CONFIRMADO"
}
```

`GET /disponibilidade`, resposta 200:

```json
{
  "profissional_id": "22222222-2222-2222-2222-222222222222",
  "data": "2026-10-28",
  "horarios_livres": [
    {"inicio": "2026-10-28T09:00:00-03:00", "fim": "2026-10-28T09:30:00-03:00"},
    {"inicio": "2026-10-28T09:30:00-03:00", "fim": "2026-10-28T10:00:00-03:00"}
  ]
}
```

### Eventos no Kafka

| Tópico | Partições | Chave | Producer | Consumers (group id) |
|---|---|---|---|---|
| `agendamento.criado` | 3 | `profissional_id` | agendamento-service | `notificacao-service`, `disponibilidade-service` |
| `agendamento.cancelado` | 3 | `profissional_id` | agendamento-service | `notificacao-service`, `disponibilidade-service` |

Valor da mensagem, JSON em UTF-8 (no cancelado, só muda o `tipo`):

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

A entrega é "pelo menos uma vez", então o consumer precisa aguentar receber a mesma mensagem duas vezes.

### Keycloak

- Realm `barbearia`.
- Client `bff-gateway`, confidencial, secret `bff-secret`, *direct access grants* ligado, com o mapper de audience `bff-gateway` (igual ao PizzaExpress).
- Realm roles `cliente` e `gestor`.
- Usuários de teste (ambiente local):

| Usuário | Senha | Role |
|---|---|---|
| `cliente1` | `cliente123` | `cliente` |
| `cliente2` | `cliente123` | `cliente` |
| `gestor1` | `gestor123` | `gestor` |

Para obter um token pelo host:

```bash
curl -s -X POST http://localhost:8080/realms/barbearia/protocol/openid-connect/token \
  -d grant_type=password -d client_id=bff-gateway -d client_secret=bff-secret \
  -d username=cliente1 -d password=cliente123 | jq -r .access_token
```

### Dados fixos

O barbearia-service cria estes registros ao subir. O resto do sistema usa os mesmos IDs sem consultar o barbearia-service.

| O quê | ID | Dados |
|---|---|---|
| Barbearia | `11111111-1111-1111-1111-111111111111` | Barbearia Centro, Rua da Bahia 1000 |
| Profissional | `22222222-2222-2222-2222-222222222222` | Carlos |
| Serviço | `33333333-3333-3333-3333-333333333333` | Corte, 30 min, R$ 40,00 |

Horários sempre em `America/Sao_Paulo`, offset `-03:00`.

## Como testar sozinho

Ninguém precisa esperar a infra do João. A infra do PizzaExpress tem os mesmos containers e a mesma rede.

1. Suba só a infra do PizzaExpress:

   ```bash
   cd ~/pizzaexpress/pizzaexpress-ambiente
   docker compose -f infrastructure/docker-compose.yml up -d
   ```

2. Crie o nosso banco dentro desse Postgres. Salve o SQL da seção [Banco](#banco) num arquivo `init.sql` e rode:

   ```bash
   docker exec postgres psql -U pizzaexpress -d pizzaexpress -c "CREATE DATABASE barbearia"
   docker exec -i postgres psql -U pizzaexpress -d barbearia < init.sql
   ```

3. Rode o seu serviço em container, na rede `observability`, com as variáveis do contrato. Exemplo com o agendamento:

   ```bash
   docker build -t agendamento-service services/agendamento-service
   docker run --rm --name agendamento-service --network observability -p 8012:8012 \
     -e SPRING_DATASOURCE_URL="jdbc:postgresql://postgres:5432/barbearia?currentSchema=agendamento" \
     -e SPRING_DATASOURCE_USERNAME=agendamento_svc -e SPRING_DATASOURCE_PASSWORD=agendamento_pass \
     -e KAFKA_BOOTSTRAP_SERVERS=kafka:9092 agendamento-service
   ```

   Rode em container, não direto no host. O Kafka anuncia o endereço `kafka:9092`, que só resolve dentro da rede Docker.

4. Quem consome eventos publica mensagens de teste no Kafka UI (<http://localhost:8090>): Topics, crie o tópico com 3 partições se ainda não existir, depois *Produce Message*, com a chave igual ao `profissional_id` e o valor igual ao JSON do contrato.

5. Ver o banco: `docker exec -it postgres psql -U pizzaexpress -d barbearia`.

## Allainn: C4, slides e revisão

**Arquivos que você pode mexer:** `docs/arquitetura/`, `docs/adr/README.md`, `docs/adr/0001` a `docs/adr/0005`, `docs/questoes-abertas.md`, `contracts/README.md`, `README.md`, slides (fora do repositório).

1. **C4 nível 1.** Pessoas: Cliente e Gestor da barbearia. Sistemas externos: Keycloak e provedor de mensagens (simulado). Tirar Profissional, Administrador e gateway de pagamento, que não existem no código.
2. **C4 nível 2.** Os 5 containers do contrato, Kafka, PostgreSQL e Keycloak. Setas: pessoas → BFF (REST com JWT); BFF → Keycloak (JWKS); BFF → barbearia, agendamento e disponibilidade (REST); agendamento → Kafka (publica `agendamento.criado` e `agendamento.cancelado`); Kafka → notificação e disponibilidade (consomem os dois tópicos); cada serviço → seu schema no PostgreSQL; notificação → provedor de mensagens (simulado, grava no log). Tirar `agendamento.solicitado`, `expediente.alterado`, agendamento → barbearia e agendamento → Keycloak. Anotar a tecnologia em cada container e um texto em cada seta.
3. Atualizar o Mermaid em `docs/arquitetura/README.md` e o board do Miro. Exportar as duas imagens para os slides.
4. Na segunda (26/10), atualizar o índice em `docs/adr/README.md` com o status final de todos os ADRs e pôr no topo de `docs/questoes-abertas.md` um aviso de que as questões foram encerradas pelo roadmap.
5. **Slides (cerca de 15).** Problema e volume de uso (números do ADR-0003); C4 1; C4 2; um slide por decisão, com o porquê (linguagens, Kafka, lock com constraint de exclusão, CQRS na disponibilidade, segurança no BFF, Clean Architecture, um banco com schema por serviço, CI/CD e observabilidade); roteiro da demo; trade-offs aceitos (o que ficou fora e por quê).
6. Dividir a fala: cada pessoa apresenta a decisão da sua parte. Total de 20 minutos.
7. Revisar e aprovar os PRs no mesmo dia em que forem abertos.
8. Depois do primeiro push do pipeline do João, tornar público o pacote `barbearia-service` no GHCR (página do pacote no GitHub, *Package settings*, *Change visibility*).

**Pronto quando:** C4 1 e 2 batem com o código integrado no domingo; slides prontos na segunda.

## João: infra, CI/CD e Grafana

**Arquivos que você pode mexer:** `infra/`, `.github/workflows/`, `scripts/up.sh`, `scripts/down.sh`, `scripts/deploy.sh`, `.gitignore`, `docs/adr/0011`, `docs/adr/0013`.

1. Copie `pizzaexpress-ambiente/infrastructure/` para `infra/` (o `docker-compose.yml` e a pasta `config/`). Não copie `data/`; ponha `infra/data/` no `.gitignore`.
2. No `infra/docker-compose.yml`:
   - Postgres com `POSTGRES_DB=barbearia`, `POSTGRES_USER=barbearia`, `POSTGRES_PASSWORD=barbearia`. Troque `config/postgres/init.sql` pelo SQL da seção [Banco](#banco).
   - Kafka UI com `KAFKA_CLUSTERS_0_NAME=barbearia`.
   - Um serviço `kafka-init`, que roda uma vez depois do Kafka ficar saudável e cria os dois tópicos com 3 partições (`kafka-topics --create --if-not-exists ...`).
   - Os 5 serviços do contrato, com `build: ../services/<container>`, as variáveis do contrato, `restart: unless-stopped`, rede `observability` e as portas da tabela. Os que usam Kafka ganham `depends_on: kafka-init: condition: service_completed_successfully`, para os tópicos já existirem com 3 partições quando o consumer subir. No `barbearia-service`, ponha também `image: ghcr.io/allainn/barbearia-multiplataforma/barbearia-service:latest`, para o deploy do pipeline funcionar.
   - Mantenha o nome da rede, `observability`.
3. `scripts/up.sh`: sobe o compose com `--build` e, se `scripts/keycloak-seed.sh` existir, roda o seed. `scripts/down.sh`: derruba o compose.
4. **Grafana.** Mantenha os dashboards do PizzaExpress em `config/grafana/provisioning/dashboards/`. Apague o `kubernetes.json`. No `latencia.json`, troque os nomes de serviço nos filtros `service_name` e nos títulos: `catalog-service` vira `barbearia-service`, `order-service` vira `agendamento-service`, `delivery-service` vira `disponibilidade-service`, `bff-gateway` continua `bff-gateway`. Confira se os outros dashboards também filtram por nome e troque do mesmo jeito.
5. **Pipeline.** Crie `.github/workflows/barbearia-service.yml`:
   - Dispara em `push` para `main` e para branches `demo/**` quando muda `services/barbearia-service/**`, e também em `workflow_dispatch`.
   - `permissions: packages: write, contents: read`.
   - Faz login no GHCR com o `GITHUB_TOKEN`, builda `services/barbearia-service` e publica `ghcr.io/allainn/barbearia-multiplataforma/barbearia-service` com as tags `latest` e o SHA do commit (`docker/login-action` e `docker/build-push-action`).
6. `scripts/deploy.sh`: `docker compose -f infra/docker-compose.yml pull barbearia-service` e depois `docker compose -f infra/docker-compose.yml up -d --no-build barbearia-service`.
7. Ensaie o roteiro do CI/CD: mude um texto no barbearia-service numa branch `demo/ci`, dê push, espere o Actions ficar verde, rode `scripts/deploy.sh`, chame `GET /barbearias` e mostre a latência no dashboard de latência. O header `X-Demo-Delay-Ms: 800` deixa o pico visível no gráfico.
8. **ADR-0011** (um PostgreSQL, schema e usuário por serviço, tabelas com `barbearia_id`) e **ADR-0013** (GitHub Actions, GHCR, deploy com `docker compose pull`, stack Grafana do PizzaExpress; Argo CD e Minikube ficaram fora por prazo).

Enquanto os serviços não existem no repositório, suba só a infra (`docker compose up -d postgres kafka kafka-init kafka-ui keycloak grafana ...`). Para ensaiar o pipeline antes do barbearia-service ficar pronto, use uma cópia do `catalog-service` do PizzaExpress na sua branch.

**Pronto quando:**

- `scripts/up.sh` numa máquina limpa sobe tudo, e `docker compose ps` mostra os containers saudáveis.
- O Kafka UI mostra os dois tópicos com 3 partições.
- `psql` no banco `barbearia` mostra os 4 schemas.
- Um push numa branch `demo/**` gera a imagem no GHCR, e `scripts/deploy.sh` troca o container pela nova versão.
- O dashboard de latência mostra `barbearia-service` e `agendamento-service`.

## Evandro: Keycloak e BFF

**Arquivos que você pode mexer:** `services/bff-gateway/`, `scripts/keycloak_seed.py`, `scripts/keycloak-seed.sh`, `docs/adr/0009`.

### Seed do Keycloak

1. Copie `pizzaexpress-ambiente/services/bff-gateway/scripts/keycloak_seed.py` para `scripts/keycloak_seed.py` e adapte ao contrato: realm `barbearia`, client `bff-gateway` com secret `bff-secret` e o mapper de audience, roles `cliente` e `gestor`, os 3 usuários da tabela (e-mail `<usuario>@barbearia.local`). Apague o client de PKCE e os usuários de pizza. O script continua idempotente.
2. `scripts/keycloak-seed.sh` roda o seed num container, sem depender de Python no host. Ele é chamado da raiz do repositório:

   ```bash
   docker run --rm --network observability -v "$PWD/scripts:/s" \
     -e KEYCLOAK_URL=http://keycloak:8080 python:3.12-slim \
     sh -c "pip install -q requests && python /s/keycloak_seed.py"
   ```

### BFF

1. Copie `pizzaexpress-ambiente/services/bff-gateway-java` para `services/bff-gateway`. Renomeie o pacote `com.pizzaexpress.bff` para `com.barbearia.bff`, o `artifactId` no `pom.xml` para `bff-gateway` e o `SERVICE_NAME` do `TelemetryConfig` para `bff-gateway`.
2. Apague os clients, controllers, use cases e DTOs de pizza, pedido e entrega. Crie três clients, `BarbeariaClient`, `AgendamentoClient` e `DisponibilidadeClient`, lendo `BARBEARIA_URL`, `AGENDAMENTO_URL` e `DISPONIBILIDADE_URL`. Copie o circuit breaker do `OrderClient`. Retry só em `GET`.
3. Cada client encaminha método, caminho, query string e corpo sem alterar nada e acrescenta o header `X-User-ID` com o `sub` do usuário. Ele devolve o status e o corpo do serviço como vieram, incluindo 201, 204, 404 e 409. Um jeito simples é cada controller retornar `ResponseEntity<String>` com o status do serviço e `Content-Type: application/json`.
4. Controllers com as rotas da tabela do contrato. Em cada rota, `authService.getCurrentUser(request)` (401) e, onde a tabela pede role, `authService.requireRole(user, "gestor")` ou `"cliente"` (403).
5. O `KeycloakJwtValidator` lê as roles de `realm_access.roles`, então as roles do seed já chegam. O modo bypass liga quando `KEYCLOAK_URL` está vazio. Troque as roles do usuário de bypass para `cliente` e `gestor` e garanta que o compose sempre define `KEYCLOAK_URL`.
6. Mantenha `GlobalExceptionHandler` (401 com `WWW-Authenticate`, 403, 503), `TelemetryFilter`, `DemoLatencyFilter` e `HealthController`.
7. **ADR-0009** como *Aceito*: Keycloak 26, validação só no BFF (opção A); o híbrido (C) e o 403 entre barbearias ficaram fora por prazo; roles `cliente` e `gestor`.

Para testar sem os outros serviços: o 401 e o 403 acontecem antes da chamada ao serviço. Uma rota permitida com o serviço fora do ar devolve 503, o que prova que o token passou.

**Pronto quando:**

- O seed roda duas vezes seguidas sem erro, e o token de `cliente1` tem `cliente` em `realm_access.roles` e `bff-gateway` em `aud`.
- `curl -i http://localhost:8010/barbearias` sem token devolve 401.
- Um token com a assinatura alterada (troque um caractere do fim) devolve 401.
- `POST /barbearias` com token de `cliente1` devolve 403.
- `POST /barbearias` com token de `gestor1` chega ao barbearia-service (201 se ele estiver no ar, 503 se não).
- Com o agendamento no ar, o `cliente_id` gravado é o `sub` do token.

## Pedro: agendamento-service

**Arquivos que você pode mexer:** `services/agendamento-service/`, `scripts/disputa.sh`, `docs/adr/0007`, `docs/adr/0010`, `docs/adr/0012`.

1. Copie `pizzaexpress-ambiente/services/order-service-java` para `services/agendamento-service`. Renomeie o pacote `com.pizzaexpress.order` para `com.barbearia.agendamento`, o `artifactId` para `agendamento-service` e o `SERVICE_NAME` do `TelemetryConfig` para `agendamento-service`. Mantenha a porta 8012 e a estrutura `domain`, `application`, `infrastructure`.
2. **Domínio.** Troque `Order` e `OrderItem` por `Agendamento` (`id`, `barbeariaId`, `profissionalId`, `servicoId`, `clienteId`, `inicio`, `fim`, `status`), com `StatusAgendamento` (`CONFIRMADO`, `CANCELADO`). Eventos de domínio `AgendamentoCriado` e `AgendamentoCancelado`. O aggregate valida `fim > inicio` e `inicio` no futuro (erro 422 pelo handler que já existe).
3. **Tabela.** No `MigrationRunner`:

   ```sql
   CREATE TABLE IF NOT EXISTS agendamento.agendamento (
       id              UUID         PRIMARY KEY,
       barbearia_id    UUID         NOT NULL,
       profissional_id UUID         NOT NULL,
       servico_id      UUID         NOT NULL,
       cliente_id      VARCHAR(100) NOT NULL,
       inicio          TIMESTAMPTZ  NOT NULL,
       fim             TIMESTAMPTZ  NOT NULL,
       status          VARCHAR(20)  NOT NULL DEFAULT 'CONFIRMADO',
       criado_em       TIMESTAMPTZ  NOT NULL DEFAULT now(),
       CHECK (fim > inicio),
       CONSTRAINT sem_sobreposicao EXCLUDE USING gist (
           profissional_id WITH =,
           tstzrange(inicio, fim) WITH &&
       ) WHERE (status = 'CONFIRMADO')
   );
   ```

   A extensão `btree_gist` vem do SQL do contrato.
4. **`POST /agendamentos`.** Lê o corpo do contrato e o header `X-User-ID` (sem ele, 400). Gera o `id`, grava com `status = CONFIRMADO` e responde 201 com o JSON do contrato. Se o Postgres recusar pela constraint, o JdbcTemplate lança `DataIntegrityViolationException` com SQLState `23P01` na causa. Converta isso numa exceção de horário indisponível e responda 409 com `{"detail": "Horário indisponível para este profissional"}`.
5. **`DELETE /agendamentos/{id}`.** Muda o status para `CANCELADO` e responde 204. Se não existir, 404. Se já estiver cancelado, 204 sem publicar de novo.
6. **Eventos.** Adapte o `KafkaEventProducer`. Tópico `agendamento.criado` ou `agendamento.cancelado`, chave `profissional_id` (hoje o `ProducerRecord` vai sem chave; use `new ProducerRecord<>(topico, profissionalId, json)`), valor no envelope do contrato com `evento_id` novo a cada evento. Publique logo depois da gravação no banco ter dado certo. Se a publicação falhar, só registre no log, sem desfazer a reserva.
7. **`scripts/disputa.sh`.** Dispara duas reservas iguais ao mesmo tempo (`&` e `wait`) e imprime o status de cada uma. Use a variável `BASE_URL` (padrão `http://localhost:8012`) e a variável `TOKEN` opcional: com `TOKEN`, manda `Authorization: Bearer $TOKEN` e usa `BASE_URL=http://localhost:8010` para passar pelo BFF; sem `TOKEN`, manda `X-User-ID` direto. Gere um horário futuro a cada execução (ex.: amanhã às 18:00 mais um número aleatório de blocos de 30 min) para o script poder rodar várias vezes.
8. **ADR-0007** como *Aceito*, reescrito com a opção C: constraint de exclusão, 409 para quem perde a disputa. Registre que a opção D foi considerada e ficou fora por prazo. Descarte a revisão local antiga deste ADR, que descrevia a D. **ADR-0010** como *Aceito*: Clean Architecture com DDD tático no agendamento. **ADR-0012** como *Rejeitado*: Outbox fora por prazo; o evento é publicado logo depois do commit, e o risco de perder um evento se o serviço cair entre o commit e o envio fica registrado.

**Pronto quando:**

- `scripts/disputa.sh` imprime um 201 e um 409, sempre.
- Um `POST` com horário livre devolve 201, e a linha aparece em `agendamento.agendamento`.
- O Kafka UI mostra a mensagem em `agendamento.criado`, com a chave igual ao `profissional_id` e o envelope do contrato.
- `DELETE` devolve 204, publica em `agendamento.cancelado`, e o mesmo horário pode ser reservado de novo.

## Daniel: notificacao-service

**Arquivos que você pode mexer:** `services/notificacao-service/`, `docs/adr/0006`.

1. Copie `pizzaexpress-ambiente/services/notification-service` para `services/notificacao-service`. Renomeie o pacote `notification` para `notificacao` (pasta `src/`, imports, `pyproject.toml`, `CMD` do `Dockerfile` com porta 8004) e o nome do serviço no `setup_telemetry` para `notificacao-service`.
2. No consumer (`infrastructure/kafka/consumer.py`): `TOPICS = ["agendamento.criado", "agendamento.cancelado"]` e `group_id="notificacao-service"`.
3. Tabela, nas migrations:

   ```sql
   CREATE TABLE IF NOT EXISTS notificacao.envio (
       id          UUID         PRIMARY KEY,
       evento_id   UUID         NOT NULL UNIQUE,
       tipo        VARCHAR(50)  NOT NULL,
       cliente_id  VARCHAR(100) NOT NULL,
       mensagem    TEXT         NOT NULL,
       payload     JSONB        NOT NULL,
       enviado_em  TIMESTAMPTZ  NOT NULL DEFAULT now()
   );
   ```

4. Para cada mensagem, monte o texto. Criado: `Seu horário de <inicio> está confirmado.` Cancelado: `Seu horário de <inicio> foi cancelado.` Formate `<inicio>` como `28/10 18:00`. Grave com `INSERT ... ON CONFLICT (evento_id) DO NOTHING`. Se nenhuma linha entrou, o evento é repetido: registre no log `evento <evento_id> repetido, ignorado` e não envie nada.
5. O provedor de mensagens é simulado. Adapte o `log_notifier.py` para escrever no log `mensagem enviada para <cliente_id>: <texto>`.
6. Mantenha `GET /health`. Troque a rota de listagem por `GET /notificacoes`, com as últimas 20 linhas de `notificacao.envio`, para conferir na demo.
7. **ADR-0006** como *Aceito*: REST síncrono do BFF para os serviços; Kafka com os dois tópicos, 3 partições, chave `profissional_id`, envelope com `evento_id`, entrega "pelo menos uma vez" e consumers idempotentes; DLQ e `expediente.alterado` ficaram fora por prazo.

**Pronto quando:**

- Uma mensagem publicada à mão no Kafka UI em `agendamento.criado` gera a linha no log e uma linha em `notificacao.envio`.
- Publicar a mesma mensagem de novo (mesmo `evento_id`) gera só o log de repetido.
- `agendamento.cancelado` gera a mensagem de cancelamento.
- `GET http://localhost:8004/notificacoes` lista os envios.

## Gabriel: disponibilidade-service (lado de leitura do CQRS)

**Arquivos que você pode mexer:** `services/disponibilidade-service/`, `docs/adr/0008`.

1. Copie `pizzaexpress-ambiente/services/delivery-service` para `services/disponibilidade-service`. Renomeie o pacote `delivery` para `disponibilidade` (pasta `src/`, imports, `pyproject.toml`, `CMD` do `Dockerfile` com porta 8003) e o nome do serviço no `setup_telemetry` para `disponibilidade-service`. Apague o domínio de entrega e o producer Kafka: este serviço só consome.
2. Consumer nos tópicos `agendamento.criado` e `agendamento.cancelado`, `group_id="disponibilidade-service"`. Aproveite o padrão do `consumer.py` copiado (thread, retry em `OperationalError`).
3. Tabela, nas migrations:

   ```sql
   CREATE TABLE IF NOT EXISTS disponibilidade.horario_ocupado (
       agendamento_id  UUID        PRIMARY KEY,
       barbearia_id    UUID        NOT NULL,
       profissional_id UUID        NOT NULL,
       inicio          TIMESTAMPTZ NOT NULL,
       fim             TIMESTAMPTZ NOT NULL
   );
   CREATE INDEX IF NOT EXISTS horario_ocupado_prof_inicio
       ON disponibilidade.horario_ocupado (profissional_id, inicio);
   ```

4. `agendamento.criado` faz `INSERT ... ON CONFLICT (agendamento_id) DO NOTHING`. `agendamento.cancelado` faz `DELETE ... WHERE agendamento_id = ...`. Assim a mesma mensagem duas vezes não muda o resultado.
5. `GET /disponibilidade?profissional_id=<uuid>&data=AAAA-MM-DD` (os dois parâmetros obrigatórios). Monte a grade do dia das 09:00 às 18:00 em `America/Sao_Paulo`, em blocos de 30 min (18 blocos). Um bloco está ocupado se existir linha com `inicio < fim_do_bloco` e `fim > inicio_do_bloco`. Responda no formato do contrato, só com os blocos livres, em ordem e com offset `-03:00`.
6. Mantenha `GET /health`.
7. **ADR-0008** como *Aceito*: CQRS com o read model num serviço separado, atualizado pelos eventos; a grade de expediente é fixa e o `expediente.alterado` ficou fora por prazo; a consistência é eventual (a grade pode demorar alguns milissegundos para refletir a reserva).

**Pronto quando:**

- Sem nenhum evento, a consulta de 28/10 devolve 18 horários livres.
- Uma mensagem em `agendamento.criado` das 18:00 às 18:30 (publicada à mão no Kafka UI) tira o bloco das 18:00 da resposta.
- A mesma mensagem duas vezes não quebra nada, e o `agendamento.cancelado` do mesmo `agendamento_id` devolve o bloco.
- Falta de parâmetro devolve 422.

## Guilherme: barbearia-service e roteiro da demo

**Arquivos que você pode mexer:** `services/barbearia-service/`, `scripts/demo.sh`.

### barbearia-service

1. Copie `pizzaexpress-ambiente/services/catalog-service` para `services/barbearia-service`. Renomeie o pacote `catalog` para `barbearia` (pasta `src/`, imports, `pyproject.toml`, `CMD` do `Dockerfile` com porta 8001) e o nome do serviço no `setup_telemetry` para `barbearia-service`. Apague os routers de pizza (`/pizzas`, `/v1`, `/v2`), o `pizza_enrichment.py`, o `scripts/seed.py` e as rotas `/demo/*`.
2. Tabelas, nas migrations:

   ```sql
   CREATE TABLE IF NOT EXISTS barbearia.barbearia (
       id       UUID         PRIMARY KEY,
       nome     VARCHAR(100) NOT NULL,
       endereco VARCHAR(200) NOT NULL
   );
   CREATE TABLE IF NOT EXISTS barbearia.profissional (
       id           UUID         PRIMARY KEY,
       barbearia_id UUID         NOT NULL REFERENCES barbearia.barbearia(id),
       nome         VARCHAR(100) NOT NULL
   );
   CREATE TABLE IF NOT EXISTS barbearia.servico (
       id           UUID          PRIMARY KEY,
       barbearia_id UUID          NOT NULL REFERENCES barbearia.barbearia(id),
       nome         VARCHAR(100)  NOT NULL,
       duracao_min  INT           NOT NULL CHECK (duracao_min > 0),
       preco        NUMERIC(10,2) NOT NULL CHECK (preco > 0)
   );
   ```

3. Ao subir, depois das migrations, insira os [dados fixos](#dados-fixos) com `ON CONFLICT (id) DO NOTHING`.
4. As 6 rotas de barbearia da tabela do contrato. `POST` gera o `id` e devolve 201 com o objeto criado. Barbearia inexistente nas rotas `/barbearias/{id}/...` devolve 404. Corpo inválido devolve 422 (padrão do FastAPI). Os objetos devolvidos usam os mesmos nomes de campo das tabelas.
5. Mantenha `GET /health` e o middleware de latência. O João vai mudar um texto deste serviço ao vivo para mostrar o pipeline, então não precisa preparar nada para isso.

### scripts/demo.sh

O roteiro que roda na apresentação, tudo pelo BFF (`http://localhost:8010`). Dá para escrever agora, a partir do contrato, e testar cada passo quando o serviço correspondente subir.

1. Obter os tokens de `cliente1`, `cliente2` e `gestor1` (comando na seção [Keycloak](#keycloak)). Usa `curl` e `jq`.
2. Cada passo imprime um título, o comando, o status HTTP e o corpo formatado, e espera Enter (`read -p`) antes do próximo.
3. Passos:
   1. `GET /barbearias` sem token: 401.
   2. `POST /barbearias/1111.../servicos` com token de `cliente1`: 403.
   3. Mesmo `POST` com token de `gestor1` (Barba, 20 min, R$ 30,00): 201.
   4. `GET /disponibilidade?profissional_id=2222...&data=<amanhã>` com `cliente1`: lista de horários.
   5. Disputa: `cliente1` e `cliente2` fazem `POST /agendamentos` no mesmo horário ao mesmo tempo (`&` e `wait`): um 201 e um 409.
   6. Pausa para mostrar o evento no Kafka UI e o log do `notificacao-service` (`docker logs notificacao-service --tail 5`).
   7. Mesma consulta do passo 4: o horário reservado sumiu.
   8. `DELETE /agendamentos/<id do 201>` com o token de quem reservou: 204.
   9. Mesma consulta: o horário voltou.
4. A data é sempre amanhã (`date -d tomorrow +%F`), e o horário da disputa é escolhido entre os livres do passo 4, para o script rodar várias vezes seguidas.

**Pronto quando:**

- Com o barbearia-service no ar: `GET http://localhost:8001/barbearias` devolve a Barbearia Centro, e as rotas de profissionais e serviços devolvem Carlos e Corte.
- `POST` de serviço numa barbearia inexistente devolve 404.
- No domingo, `scripts/demo.sh` roda do começo ao fim com o sistema integrado, com os status esperados em cada passo.

## Integração (domingo, 25/10)

1. Todos os PRs mergeados na `main`.
2. `scripts/up.sh` numa máquina só.
3. `scripts/demo.sh` do começo ao fim.
4. Para cada passo que falhar, o dono da parte corrige no mesmo dia. O que não rodar até a noite sai dos slides e do C4.
