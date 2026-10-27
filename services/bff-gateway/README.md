# bff-gateway

Única entrada pública da plataforma. Autentica a requisição (JWT do Keycloak), aplica a autorização por role e encaminha para o serviço de domínio responsável. Os serviços internos não publicam porta no host: só o BFF é alcançável de fora.

Decisões que este serviço implementa: [ADR-0009](../../docs/adr/0009-seguranca-keycloak-e-validacao-jwt.md) (Keycloak como IdP), [ADR-0014](../../docs/adr/0014-modelo-de-autorizacao-rbac.md) (RBAC) e [ADR-0015](../../docs/adr/0015-onde-autenticar-e-autorizar.md) (autenticação e autorização na borda).

Contrato da API: [`openapi.yaml`](openapi.yaml) (OpenAPI 3.0.3, mantido à mão; não é servido pelo BFF).

## Fluxo de uma requisição

```
cliente ──Authorization: Bearer <jwt>──▶ BFF :8010
                                          │ 1. TelemetryFilter: span SERVER, trace_id no log
                                          │ 2. Spring Security: valida assinatura (JWKS), exp, iss, aud   → 401
                                          │ 3. RegrasDeAutorizacao: role exigida pela rota                → 403
                                          │ 4. Controller → ServicoClient: repassa método, path, query e corpo,
                                          │    acrescenta X-User-ID = sub e traceparent; remove o Authorization
                                          ▼
                              barbearia-service :8001 | agendamento-service :8012 | disponibilidade-service :8003
```

O BFF não interpreta o corpo das respostas: status e JSON do serviço voltam como estão. Só gera resposta própria em 401, 403 e 503.

## Autenticação

- Token: JWT RS256 emitido pelo Keycloak, realm `barbearia`.
- Verificações: assinatura contra o JWKS de `${KEYCLOAK_URL}/protocol/openid-connect/certs`, `exp`, `iss` igual a `KEYCLOAK_URL` e `aud` contendo `KEYCLOAK_CLIENT_ID`.
- Falha: **401** com `WWW-Authenticate: Bearer realm="barbearia", error="invalid_token", error_description="..."` (RFC 6750). O corpo é sempre `{"detail": "Token ausente ou inválido"}`; o motivo só vai no header.
- O JWKS fica em cache no `NimbusJwtDecoder`; o BFF só vai ao Keycloak de novo quando aparece um `kid` desconhecido.

## Autorização

Roles lidas de `realm_access.roles` e convertidas em `ROLE_<role>` (`RealmRolesConverter`). As regras estão em um só lugar, `RegrasDeAutorizacao`, e terminam em `anyRequest().denyAll()`: rota não declarada é negada.

| Rota | Exige |
|---|---|
| `GET /health` | nada |
| `GET /barbearias`, `GET /barbearias/{id}/profissionais`, `GET /barbearias/{id}/servicos` | autenticado |
| `GET /disponibilidade` | autenticado |
| `POST /barbearias`, `POST /barbearias/{id}/profissionais`, `POST /barbearias/{id}/servicos` | role `gestor` |
| `POST /agendamentos`, `DELETE /agendamentos/{id}` | role `cliente` |

Role insuficiente: **403** `{"detail": "Permissão insuficiente para esta operação"}`.

Regras por recurso ficam nos serviços: o agendamento-service usa `X-User-ID` como `cliente_id` da reserva e só deixa o dono cancelar (404 para os outros). O isolamento por barbearia do gestor não existe nesta versão (risco aceito no ADR-0014).

## Configuração

| Variável | Padrão | Uso |
|---|---|---|
| `KEYCLOAK_URL` | *(vazio)* | URL do realm e `iss` esperado, ex.: `http://keycloak:8080/realms/barbearia`. **Vazio liga o modo bypass.** |
| `KEYCLOAK_CLIENT_ID` | `bff-gateway` | valor exigido em `aud` |
| `BARBEARIA_URL` | `http://barbearia-service:8001` | destino de `/barbearias/**` |
| `AGENDAMENTO_URL` | `http://agendamento-service:8012` | destino de `/agendamentos/**` |
| `DISPONIBILIDADE_URL` | `http://disponibilidade-service:8003` | destino de `/disponibilidade` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://otel-collector:4318` | OTLP/HTTP para traces e logs |

O `iss` do token é a URL pela qual o Keycloak foi chamado. Por isso o compose fixa `KC_HOSTNAME=http://keycloak:8080`: o token obtido via `localhost:8080` sai com `iss` = `http://keycloak:8080/realms/barbearia`, que é o que o BFF espera.

### Modo bypass

Com `KEYCLOAK_URL` vazio, `BypassSecurityConfig` entra no lugar de `KeycloakSecurityConfig`: toda requisição é tratada como do usuário `usuario-bypass`, com as duas roles. Serve só para rodar o BFF fora do compose, sem Keycloak. O compose sempre define a variável.

## Resiliência

`ServicoClient` usa `RestClient` com timeout de conexão 2 s e leitura 5 s, e Resilience4j por serviço de destino:

- **Circuit breaker:** janela de 10 chamadas, mínimo 5, abre com 50% de falha, fica aberto 10 s.
- **Retry:** só em `GET`, 3 tentativas com 200 ms, em erro de conexão ou 5xx. `POST` e `DELETE` não são repetidos, para não duplicar reserva nem mascarar um 409.

Serviço fora ou breaker aberto: **503** `{"detail": "<serviço> indisponível"}`.

## Observabilidade

- Traces via OpenTelemetry SDK (`service.name=bff-gateway`): span `SERVER` por requisição e span `CLIENT` por chamada a serviço; `traceparent` propagado, então o trace segue até o serviço de domínio.
- Logs em JSON com `trace_id` e `span_id` (`logback-spring.xml` + appender OTel).
- Header `X-Demo-Delay-Ms: <1..5000>` atrasa a resposta para a latência aparecer no Grafana (`DemoLatencyFilter`).

## Como rodar

Pelo compose, a partir da raiz do repositório:

```bash
scripts/up.sh            # sobe a plataforma inteira, BFF incluído, e roda o seed do Keycloak
scripts/keycloak-seed.sh # só para refazer o realm, o client, as roles e os usuários locais
```

Só o BFF, fora do compose (modo bypass; os serviços não publicam porta no host, então é preciso publicá-las num override do Compose):

```bash
cd services/bff-gateway
BARBEARIA_URL=http://localhost:8001 mvn spring-boot:run   # exige Maven e JDK 21 locais
```

## Testes manuais

```bash
TOKEN=$(curl -s -X POST http://localhost:8080/realms/barbearia/protocol/openid-connect/token \
  -d grant_type=password -d client_id=bff-gateway -d client_secret=bff-secret \
  -d username=cliente1 -d password=cliente123 | jq -r .access_token)

curl -i http://localhost:8010/barbearias                               # 401, sem token
curl -i -H "Authorization: Bearer $TOKEN" http://localhost:8010/barbearias   # 200
curl -i -H "Authorization: Bearer $TOKEN" -X POST http://localhost:8010/barbearias \
  -H 'Content-Type: application/json' -d '{"nome":"X","endereco":"Y"}'       # 403, cliente não é gestor
```

Token adulterado: altere um caractere **do meio** da assinatura (ou do payload), não o último. O último caractere base64url da assinatura carrega só 2 bits úteis, e trocá-lo pode decodificar para a mesma assinatura; o teste então passa pelo BFF e falha adiante, parecendo um bug de autenticação que não existe.

```bash
ADULTERADO=$(echo "$TOKEN" | awk -F. '{s=$3; print $1"."$2"."substr(s,1,20)"X"substr(s,22)}')
curl -i -H "Authorization: Bearer $ADULTERADO" http://localhost:8010/barbearias   # 401, invalid_token
```

Usuários do seed: `cliente1`/`cliente123`, `cliente2`/`cliente123` (role `cliente`), `gestor1`/`gestor123` (role `gestor`).

## Estrutura

```
src/main/java/com/barbearia/bff/
├── BffGatewayApplication.java
└── infrastructure/
    ├── auth/      KeycloakSecurityConfig, BypassSecurityConfig, RegrasDeAutorizacao,
    │              RealmRolesConverter, RespostasDeSeguranca
    ├── clients/   ServicoClient (encaminhamento, CB, retry) e um client por serviço
    ├── config/    HttpClientConfig (RestClient, Resilience4j), TelemetryConfig (OTel)
    └── http/      controllers por recurso, HealthController, GlobalExceptionHandler,
                   TelemetryFilter, DemoLatencyFilter
```

Não há camada de domínio: o BFF não tem regra de negócio, só autenticação, autorização e encaminhamento.

## Fora do escopo desta versão

- Isolamento por barbearia para o gestor (ADR-0014, opção B).
- Authorization Code + PKCE: o token é obtido por *password grant*, aceitável só enquanto não há front-end (ADR-0009).
- Autenticação nos serviços de domínio: eles confiam em `X-User-ID` porque só o BFF os alcança na rede do compose (ADR-0015).
