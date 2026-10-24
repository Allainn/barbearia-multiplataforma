# ADR-0010: Arquitetura interna dos serviços

- **Status:** Aceito
- **Data:** 21/10/2026
- **Questão:** [Q18](../questoes-abertas.md#q18)
- **Afeta no diagrama:** C4 nível 3 (componentes dentro de cada serviço; fora do escopo da apresentação)
- **Aprovações:** no PR do agendamento-service

## Contexto

- A arquitetura interna é livre (Clean, Hexagonal, Onion…), desde que justificada (Aula 2 · P2 [00:08:27]).
- O professor prefere Clean para padronizar entre equipes, e aprovou outro grupo com Hexagonal em cada microsserviço (Aula 3 · P3 [00:36:59], P3 [00:56:21]).
- Vamos ter 7 pessoas mexendo em 5 serviços e parte do código gerada por IA. Um padrão único ajuda a revisar e a trocar de serviço.
- O PizzaExpress usa Clean no `catalog-service` e DDD + CQRS lite no `order-service`; os scaffolds da Aula 3 têm Clean e Hexagonal em Java.

## Opções consideradas

### A. Clean Architecture em todos os serviços

- **Prós:** um vocabulário só (entities, use cases, interface adapters, frameworks & drivers); presenters por canal combinam com o BFF; exemplos prontos em Python e Java; é a preferência do professor.
- **Contras:** mais camadas e arquivos para um serviço pequeno como o de notificação.

### B. Hexagonal em todos os serviços

- **Prós:** menos cerimônia (domínio + ports + adapters); erros ficam localizados nos adapters.
- **Contras:** deixa o miolo livre, então cada dupla pode organizar o centro de um jeito diferente.

### C. Misto justificado (Clean onde há regra de negócio, Hexagonal enxuta nos workers)

- **Prós:** custo proporcional à complexidade de cada serviço.
- **Contras:** dois padrões para explicar e para revisar.

### D. Camadas simples ("lasanha")

- **Contras:** é o contraexemplo da Aula 3. Descartada.

## Decisão

Opção **A**: Clean Architecture em todos os serviços, com **DDD tático no agendamento-service**.

Cada serviço foi copiado de um serviço do PizzaExpress que já segue Clean (`domain`, `application`, `infrastructure`) e mantém essa estrutura ([roadmap](../roadmap.md)). No agendamento-service, adaptado do `order-service-java`, ficou assim:

| Camada | Pacote em `com.barbearia.agendamento` | O que tem |
|---|---|---|
| Domínio | `domain` | Aggregate root `Agendamento` (`criar`, `cancelar`, `reconstruir`); value object `StatusAgendamento`; domain events `AgendamentoCriado` e `AgendamentoCancelado`; interface `AgendamentoRepository`; `HorarioIndisponivelException` |
| Aplicação | `application` | Command Handlers `CriarAgendamentoHandler` e `CancelarAgendamentoHandler`; DTOs de entrada e saída; porta `EventPublisher` |
| Infraestrutura | `infrastructure` | `AgendamentoController` e `GlobalExceptionHandler` (HTTP); `PostgresAgendamentoRepository` e `MigrationRunner` (JdbcTemplate); `KafkaEventProducer`; montagem dos beans em `config` |

- Regra de dependência: `domain` não importa nada de fora dele; `application` conhece o domínio e a porta `EventPublisher`; `infrastructure` implementa o repositório e a porta. No `order-service-java` a interface do publicador ficava em `infrastructure/kafka`; aqui ela foi para `application/ports`.
- Uma exceção consciente: os DTOs em `application/dtos` usam anotações do Jackson (`@JsonProperty`, para os nomes `barbearia_id`, `profissional_id`... do contrato) e do Bean Validation (`@NotNull`). São só anotações, sem lógica, e evitam uma segunda classe de DTO em `infrastructure/http` só para mapear nomes. Os handlers não usam os DTOs: recebem um `CriarAgendamentoCommand` e devolvem o aggregate.
- O aggregate é o único ponto de mudança de estado e empilha os domain events, que o handler publica depois de gravar. No cancelamento, só publica se o UPDATE mudou a linha no banco ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md), item 5).
- A regra de não sobreposição fica na constraint do PostgreSQL, não no aggregate, porque só o banco enxerga as transações concorrentes ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)).

Simplificações em relação à proposta, por prazo: sem a operação `concluir`; sem os value objects `Periodo`, `ProfissionalId` e `BarbeariaId` (os campos são `UUID` e `OffsetDateTime`); sem Outbox ([ADR-0012](0012-garantia-de-publicacao-outbox.md)). O C4 nível 3 ficou fora do escopo da apresentação.

## Consequências

- Estrutura de pastas igual nos serviços da mesma linguagem, porque todos vieram do mesmo código-base.
- Revisão de PR checa a regra de dependência (nada de SQL no controller nem regra de negócio no repositório).
- Trocar o Kafka ou o PostgreSQL mexe só em `infrastructure`; os handlers e o aggregate não mudam.
- O notificacao-service segue Clean de forma enxuta: o consumer é um adapter de entrada e o provedor de mensagens é um adapter de saída.

## Referências

- Aula 2 · P2 [00:08:27]–[00:20:32]: camadas da Clean e regra de dependência.
- Aula 2 · P3 [00:01:03]: blocos do DDD (aggregate, value object, repository, domain event).
- Aula 3 · P3 [00:26:27]–[00:36:59]: lasanha × Hexagonal × Clean.
- MARTIN, Robert C. **Clean architecture**. Prentice Hall, 2017.
- EVANS, Eric. **Domain-driven design**. Addison-Wesley, 2003.
- Código: `pizzaexpress-encontro-3/scaffolds/scaffold-clean-architecture-java/` e `scaffold-hexagonal-java/`.
