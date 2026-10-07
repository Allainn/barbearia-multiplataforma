# ADR-0010: Arquitetura interna dos serviços

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q18](../questoes-abertas.md#q18)
- **Afeta no diagrama:** C4 nível 3 (componentes dentro de cada serviço)

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

**Proposta:** opção **A**, Clean Architecture em todos, com **DDD tático no agendamento-service**:

- Aggregate root `Agendamento` (único ponto de mudança de estado: `reservar`, `cancelar`, `concluir`).
- Value objects `Periodo` (início e fim, valida sobreposição), `StatusAgendamento`, `ProfissionalId`, `BarbeariaId`.
- Domain events no passado: `AgendamentoCriado`, `AgendamentoCancelado`.
- Interface do repositório no domínio; implementação no adapter (PostgreSQL); producer Kafka (via Outbox) também no adapter.

O **C4 nível 3** do trabalho será o do agendamento-service, por concentrar DDD, lock e Outbox.

## Consequências

- Estrutura de pastas igual nos serviços da mesma linguagem (template a partir do `catalog-service` em Python e do `scaffold-clean-architecture-java`).
- Revisão de PR checa a regra de dependência (nada de SQL em presenter nem regra de negócio no controller). O professor faz isso com um agente de IA; podemos fazer o mesmo no CI.
- O notificacao-service segue Clean de forma enxuta: o consumer é um adapter de entrada e o provedor de mensagens é um adapter de saída.

## Perguntas para o grupo

- Clean em todos (A) ou alguém quer defender Hexagonal (B)?
- O C4 nível 3 fica com o agendamento-service?

## Referências

- Aula 2 · P2 [00:08:27]–[00:20:32]: camadas da Clean e regra de dependência.
- Aula 2 · P3 [00:01:03]: blocos do DDD (aggregate, value object, repository, domain event).
- Aula 3 · P3 [00:26:27]–[00:36:59]: lasanha × Hexagonal × Clean.
- MARTIN, Robert C. **Clean architecture**. Prentice Hall, 2017.
- EVANS, Eric. **Domain-driven design**. Addison-Wesley, 2003.
- Código: `pizzaexpress-encontro-3/scaffolds/scaffold-clean-architecture-java/` e `scaffold-hexagonal-java/`.
