# ADR-0012: Garantia de publicação de eventos (Outbox Pattern)

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q16](../questoes-abertas.md#q16)
- **Afeta no diagrama:** C4 nível 2 (seta agendamento-service → Kafka); C4 nível 3 do agendamento-service

## Contexto

- O agendamento-service grava a reserva no PostgreSQL e precisa publicar `agendamento.criado` no Kafka. São dois sistemas sem transação comum (*dual write*).
- Se o commit acontecer e o Kafka estiver fora, o evento se perde: a grade de disponibilidade fica errada e o cliente não recebe a confirmação. Se publicar antes do commit e o commit falhar, sai um evento de uma reserva que não existe.
- O professor citou o Outbox, com Debezium, como opção para o trabalho (Aula 3 · P2 [00:36:18]–[00:38:05]).

## Opções consideradas

### A. Dual write: salvar e publicar no mesmo use case

- **Prós:** simples; é o que o PizzaExpress faz.
- **Contras:** os dois cenários de falha acima.

### B. Transactional Outbox com publicação por polling

O use case grava a reserva **e** uma linha na tabela `outbox` na mesma transação. Um publicador lê a `outbox` a cada poucos segundos, publica no Kafka e marca a linha como enviada.

- **Prós:** garante que todo evento de reserva confirmada será publicado; só usa o banco e o próprio serviço; fácil de demonstrar (derruba o Kafka, faz uma reserva, sobe o Kafka, o evento sai).
- **Contras:** latência do intervalo de polling; publicação "pelo menos uma vez", então os consumers precisam ser idempotentes.

### C. Outbox com Debezium (CDC lendo o WAL do PostgreSQL)

- **Prós:** sem polling; é a referência de mercado.
- **Contras:** mais um componente pesado (Kafka Connect + Debezium) e configuração de replicação lógica no PostgreSQL; mais RAM na máquina local.

## Decisão

**Proposta:** opção **B** no agendamento-service (e no barbearia-service para `expediente.alterado`, se sobrar tempo). Debezium (C) fica registrado como evolução.

## Consequências

- Tabela `outbox(id, agregado_id, tipo, payload, criado_em, publicado_em)` no schema de cada serviço que publica.
- Consumers deduplicam por `evento_id` ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).
- Demo opcional e marcante: reserva com o Kafka parado → evento sai quando o Kafka volta.

## Perguntas para o grupo

- Outbox entra no escopo (é desejável, não obrigatório)? Se o prazo apertar, aceitamos o dual write (A) com o risco documentado?
- Polling (B) ou alguém quer encarar o Debezium (C)?

## Referências

- Aula 3 · P2 [00:33:26]: a ordem importa; salvar primeiro na fonte da verdade, depois publicar.
- Aula 3 · P2 [00:36:18]–[00:38:05]: Outbox Pattern e Debezium.
- RICHARDSON, Chris. **Pattern: transactional outbox**. Disponível em: <https://microservices.io/patterns/data/transactional-outbox.html>.
