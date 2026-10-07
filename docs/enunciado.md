# Enunciado e regras do trabalho

Resumo do que o professor pede, consolidado das aulas 1 a 3. A origem de cada regra (aula e minuto da gravação) fica no material da disciplina, no arquivo `TRANSCRICAO.md` do Allainn. Quando algo mudar em aula, atualizar aqui.

**Apresentação:** Aula 6, **28/10/2026** (data calculada; conferir no Canvas) · **20 minutos** · vale **100 pontos** · pode ser gravada.

## O que é avaliado

- As **integrações entre plataformas funcionando** e a **justificativa de cada decisão arquitetural** ("escolhemos Kafka por causa de…", "escolhemos Outbox para…").
- **Não** são avaliadas regras de negócio, qualidade fina de código nem front-end. A demo pode ser feita com Postman, Insomnia ou curl.
- A devolutiva vem só depois da apresentação; pode haver desconto por falhas.

## O que o sistema precisa ter

- Tema livre, mas **não pode ser o PizzaExpress** (estudo de caso das aulas).
- Sistema **grande**, com volume de uso que justifique a arquitetura. Uma "padaria de bairro" não serve.
- Pelo menos **2 linguagens** de programação.
- **Mensageria** (Kafka, MQTT…) ou uma justificativa para tudo ser síncrono.
- **CQRS ou lock**, com justificativa.
- Arquitetura interna livre (Clean, Hexagonal, Onion…), desde que justificada.
- Linguagens, bancos, mensageria e IdP são livres. Pode usar IA para gerar código, desde que o grupo valide que funciona.
- **Nada mirabolante:** tudo o que for desenhado precisa ser implementado.

## O que mostrar na apresentação

- **C4** níveis 1 (Contexto) e 2 (Container), com a tecnologia de cada container e a descrição de cada seta. O nível 3 é desejável; o 4 deve ser evitado.
- **Segurança:** 401 para token ausente ou inválido e 403 para role insuficiente, com o modelo justificado (validação só no BFF ou em cada serviço).
- **Fluxo funcionando:** chamadas via Postman, Insomnia ou curl; mensagem chegando no broker e sendo consumida.
- **CI/CD e observabilidade:** código alterado → pipeline → publicação → chamada no endpoint → tempo da chamada no Grafana.

## Checklist de entrega

**Obrigatório**

- [ ] Grupo inscrito no Canvas
- [ ] Tema enquadrado com argumento de volume de uso ([ADR-0003](adr/0003-enquadramento-plataforma-multi-tenant.md))
- [ ] C4 nível 1 (Contexto)
- [ ] C4 nível 2 (Container), com tecnologia de cada container e descrição de cada seta
- [ ] Pelo menos 2 linguagens, com o motivo de cada escolha ([ADR-0005](adr/0005-linguagens-por-servico.md))
- [ ] Identity Provider com OAuth2/OIDC e JWT ([ADR-0009](adr/0009-seguranca-keycloak-e-validacao-jwt.md))
- [ ] Demonstração de 401 e 403
- [ ] Mensageria funcionando: producer → broker → consumer ([ADR-0006](adr/0006-comunicacao-sincrona-e-kafka.md))
- [ ] CQRS ou lock, com justificativa ([ADR-0007](adr/0007-concorrencia-na-reserva-de-horario.md), [ADR-0008](adr/0008-cqrs-na-consulta-de-disponibilidade.md))
- [ ] Pipeline de CI/CD rodando ([ADR-0013](adr/0013-entrega-continua-e-observabilidade.md))
- [ ] Observabilidade: Grafana mostrando a chamada
- [ ] Slides com as decisões e seus porquês
- [ ] Apresentação ensaiada em até 20 minutos (ou vídeo gravado)
- [ ] Trabalho postado no Canvas

**Desejável**

- [ ] C4 nível 3 de pelo menos um serviço
- [ ] Clean Architecture ou Hexagonal dentro dos serviços ([ADR-0010](adr/0010-arquitetura-interna-dos-servicos.md))
- [ ] Outbox Pattern ([ADR-0012](adr/0012-garantia-de-publicacao-outbox.md))
- [ ] PKCE no fluxo de login
- [ ] Padrões da Aula 5: BFF, resiliência (circuit breaker, retry), versionamento de API, AsyncAPI

## Roteiro sugerido da apresentação (20 min)

Sugestão inicial; o roteiro final é a questão [Q21](questoes-abertas.md#q21).

| Tempo | Parte |
|---|---|
| 2 min | Problema e por que o sistema precisa dessa arquitetura (volume de uso) |
| 3 min | C4 níveis 1 e 2 |
| 5 min | Decisões e seus porquês (linguagens, mensageria, CQRS e lock, segurança, arquitetura interna) |
| 8 min | Demo: login e 401/403 → consulta de horários → agendamento → conflito 409 → evento no Kafka → notificação → CI/CD → Grafana |
| 2 min | Fechamento e trade-offs aceitos |

## Referência de implementação: PizzaExpress

O professor entregou o PizzaExpress (Python/FastAPI e Java/Spring Boot, Keycloak, Kafka, Postgres, Grafana) como exemplo. Ele **não pode ser o tema**, mas serve de base de código. O que reaproveitar:

| Precisa de | Onde ver no pacote do professor |
|---|---|
| Ambiente com Keycloak, Kafka, Postgres e Grafana | `pizzaexpress-ambiente/infrastructure/docker-compose.yml` |
| Seed do Keycloak (realm, clients, roles, usuários) | `pizzaexpress-ambiente/scripts/keycloak-seed.sh` |
| Validação de JWT no BFF (401/403) | `pizzaexpress-ambiente/services/bff-gateway/src/bff/infrastructure/auth/` |
| Producer e consumer Kafka | `order-service/.../infrastructure/kafka/producer.py` e `delivery-service/.../infrastructure/kafka/consumer.py` |
| CQRS completo (dois serviços, dois schemas) | `pizzaexpress-encontro-3/scaffolds/scaffold-cqrs-command-java/` e `scaffold-cqrs-query-java/` |
| Clean x Hexagonal | `pizzaexpress-encontro-3/scaffolds/` |
| PKCE | `pizzaexpress-encontro-3/pkce/` |
| OpenTelemetry e dashboards do Grafana | `telemetry.py` / `TelemetryConfig` de cada serviço e `infrastructure/config/grafana/` |

Os pacotes estão no Canvas. Para rodar: Docker com pelo menos 8 GB de RAM; no Windows, dentro do WSL2, com a pasta em `~/` (não em `/mnt/c`).
