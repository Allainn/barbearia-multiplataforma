# ADR-0005: Linguagens por serviço

- **Status:** Aceito
- **Data:** 24/10/2026
- **Questão:** [Q08](../questoes-abertas.md#q08) · [Q09](../questoes-abertas.md#q09)
- **Afeta no diagrama:** C4 nível 2 (a tecnologia anotada em cada container)

## Contexto

- O trabalho exige **pelo menos 2 linguagens**, com o porquê de cada uma.
- O professor aceita dois critérios: o que a linguagem faz melhor e a mão de obra disponível, ou seja, a proficiência do grupo (Aula 1 [00:21:16]; Aula 2 · P3 [00:29:03]).
- O PizzaExpress tem cada serviço em **Python/FastAPI e Java/Spring Boot**, com JWT, Kafka, PostgreSQL e OpenTelemetry prontos. Reaproveitar economiza dias.

## Opções consideradas

### A. Java + Python (as mesmas do PizzaExpress)

- **Prós:** reaproveitamento direto do código do professor nas duas linguagens; cada uma tem um papel claro (ver decisão).
- **Contras:** depende de o grupo ter gente confortável com as duas.

### B. Java + outra (Go, Node.js/TypeScript ou .NET)

- **Prós:** pode casar melhor com o que o grupo usa no trabalho.
- **Contras:** perde o reaproveitamento em uma das linguagens; OpenTelemetry, cliente Kafka e JWKS precisam ser montados do zero.

### C. Três linguagens (ex.: Java + Python + Dart, com um front-end em Flutter)

- **Prós:** mais "multiplataforma" no diagrama, com um canal móvel.
- **Contras:** mais custo de build, CI e imagens; o front-end não é avaliado, então o ganho de nota não acompanha o custo.

## Decisão

Opção **A**: Java e Python, as duas linguagens do PizzaExpress.

Na Q08, o grupo votou a opção C, com o Dart (Flutter) para um front-end mínimo. O [roadmap](../roadmap.md) de 21/10 tirou o front-end do escopo (Q06), porque o professor não avalia front-end, e o Dart saiu junto.

| Container | Linguagem | Por quê | Base no PizzaExpress |
|---|---|---|---|
| bff-gateway | Java 21 · Spring Boot 3 | A base já valida o JWT do Keycloak pelo JWKS (assinatura, audience e roles) e traz Resilience4j (circuit breaker e retry) para as chamadas aos serviços | `bff-gateway-java` |
| agendamento-service | Java 21 · Spring Boot 3.3 | É o serviço transacional, onde está a disputa pelo horário. A tipagem forte ajuda no modelo DDD (aggregate, value object e domain events, [ADR-0010](0010-arquitetura-interna-dos-servicos.md)), e o tratamento de exceções do Spring devolve 409 e 422 no formato do contrato | `order-service-java` |
| barbearia-service | Python 3.12 · FastAPI | CRUD de cadastro, rápido de escrever; o Swagger sai em `/docs` sem código extra | `catalog-service` |
| disponibilidade-service | Python 3.12 · FastAPI | Leitura e consumo de eventos; o cálculo da grade de horários fica curto em Python | `delivery-service` |
| notificacao-service | Python 3.12 · FastAPI | Worker que consome o Kafka e chama o provedor externo | `notification-service` |

Os dois critérios do professor pesaram. Cada linguagem ficou onde faz melhor: Java na borda e na escrita concorrente, Python no cadastro, na leitura e no worker. E pesou a mão de obra: o grupo tem gente nas duas linguagens, e copiar o serviço do PizzaExpress na linguagem certa economizou dias numa semana de implementação.

## Consequências

- Duas toolchains (Maven e pip) e duas imagens base. Hoje o pipeline publica só o barbearia-service ([ADR-0013](0013-entrega-continua-e-observabilidade.md)).
- Os contratos entre serviços não dependem da linguagem: JSON nas rotas REST e nos eventos do Kafka, descritos no [tarefas.md](../tarefas.md#contrato) ([ADR-0002](0002-monorepo-e-estrutura.md)).
- O OpenTelemetry veio pronto nas duas linguagens, e o mesmo trace atravessa Java, Kafka e Python.
- Documentação das rotas: o FastAPI gera o Swagger sozinho; os serviços Java não têm Swagger, e as rotas deles estão no README e nos scripts da demo.

## Referências

- Aula 1 [00:21:16]: multiplataforma é escolher a melhor ferramenta para cada peça; a proficiência do grupo é critério válido.
- Aula 2 · P3 [00:29:03]: escolher a linguagem pelo que ela faz melhor e pela mão de obra.
- Código de partida: `pizzaexpress-ambiente/services/*` e `*-java` (pacote do Canvas).
- Votações: [Q08 (#8)](https://github.com/Allainn/barbearia-multiplataforma/issues/8), [Q09 (#9)](https://github.com/Allainn/barbearia-multiplataforma/issues/9).
