# ADR-0005: Linguagens por serviço

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q08](../questoes-abertas.md#q08)
- **Afeta no diagrama:** C4 nível 2 (a tecnologia anotada em cada container)

## Contexto

- O trabalho exige **pelo menos 2 linguagens**, com o porquê de cada uma.
- O professor aceita dois critérios: o que a linguagem faz melhor e a mão de obra disponível, ou seja, a proficiência do grupo (Aula 1 [00:21:16]; Aula 2 · P3 [00:29:03]).
- O PizzaExpress tem cada serviço em **Python/FastAPI e Java/Spring Boot**, com JWT, Kafka, Postgres e OpenTelemetry prontos. Reaproveitar economiza dias.

## Opções consideradas

### A. Java + Python (as mesmas do PizzaExpress)

- **Prós:** reaproveitamento direto do código do professor nas duas linguagens; cada uma tem um papel claro (ver decisão).
- **Contras:** depende de o grupo ter gente confortável com as duas.

### B. Java + outra (Go, Node.js/TypeScript ou .NET)

- **Prós:** pode casar melhor com o que o grupo usa no trabalho.
- **Contras:** perde o reaproveitamento em uma das linguagens; OpenTelemetry, cliente Kafka e JWKS precisam ser montados do zero.

### C. Três linguagens

- **Prós:** mais "multiplataforma" no diagrama.
- **Contras:** mais custo de build, CI e imagens, sem ganho de nota proporcional.

## Decisão

**Proposta:** opção A, se a enquete de proficiência ([Q08](../questoes-abertas.md#q08)) confirmar.

| Container | Linguagem proposta | Por quê |
|---|---|---|
| bff-gateway | Java 21 · Spring Boot 3 | Spring Security valida o JWT pelo JWKS só com configuração; Resilience4j dá circuit breaker e retry para a Aula 5; o PizzaExpress já tem `bff-gateway-java` com testes de resiliência |
| agendamento-service | Java 21 · Spring Boot 3 | É o coração transacional: consistência forte, transações declarativas, `@Version` para lock otimista, tipagem forte para o modelo DDD (aggregate, value objects) |
| barbearia-service | Python 3.12 · FastAPI | CRUD de cadastro, rápido de escrever; base pronta no `catalog-service` (Clean Architecture) |
| disponibilidade-service | Python 3.12 · FastAPI | Leitura e consumo de eventos, I/O-bound, async nativo; o cálculo de horários livres é simples de expressar em Python |
| notificacao-service | Python 3.12 · FastAPI (worker) | Consumer Kafka que chama API externa; base pronta no `notification-service` |

## Consequências

- Duas toolchains no CI (Maven e uv/pip) e duas imagens base.
- Os contratos entre serviços (REST e eventos) ficam independentes de linguagem: JSON e OpenAPI/AsyncAPI em `contracts/`.
- Se a enquete mostrar outra força no grupo (ex.: muita gente de .NET ou Node), troca-se a linguagem de um dos serviços Python e se registra aqui.

## Perguntas para o grupo

- Enquete: cada integrante diz com quais linguagens se sente à vontade (Java, Python, Go, Node/TS, .NET, outra).
- O BFF fica em Java (resiliência pronta) ou em Python (o `bff-gateway` Python do PizzaExpress também valida JWT)?

## Referências

- Aula 1 [00:21:16]: multiplataforma é escolher a melhor ferramenta para cada peça; a proficiência do grupo é critério válido.
- Aula 2 · P3 [00:29:03]: escolher a linguagem pelo que ela faz melhor e pela mão de obra.
- Código: `pizzaexpress-ambiente/services/*` e `*-java`.
