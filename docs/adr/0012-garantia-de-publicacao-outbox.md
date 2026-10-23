# ADR-0012: Garantia de publicação de eventos (Outbox Pattern)

- **Status:** Rejeitado
- **Data:** 21/10/2026
- **Questão:** [Q16](../questoes-abertas.md#q16)
- **Afeta no diagrama:** C4 nível 2 (seta agendamento-service → Kafka)
- **Aprovações:** no PR do agendamento-service

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

O Outbox foi **rejeitado** por prazo. Ele é desejável, não obrigatório, e o [roadmap](../roadmap.md) de 21/10 tirou do escopo tudo o que custava tempo. Ficou a opção **A**, dual write, com o risco documentado abaixo.

Como foi implementado no agendamento-service:

1. O handler grava primeiro no PostgreSQL e só depois publica (a ordem da Aula 3). Se a constraint recusar a reserva, nenhum evento sai.
2. O `KafkaEventProducer` publica e espera a confirmação do broker, com limite de 5 s para obter os metadados e de 10 s para a entrega.
3. Se a publicação falhar, o erro vai para o log e a reserva continua gravada. Ela não é desfeita.

Polling (B) e Debezium (C) ficam registrados como evolução, nessa ordem.

## Consequências

- Risco aceito: se o serviço cair entre o INSERT e o envio, ou se o Kafka ficar fora por mais de alguns segundos, a reserva existe sem evento. A grade do disponibilidade-service continua mostrando o horário como livre, e o cliente não recebe a confirmação. A reserva continua protegida: uma nova tentativa no mesmo horário recebe 409, porque o agendamento decide pela fonte da verdade ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)).
- Com o Kafka fora, a reserva demora até ~10 s para responder, porque espera o limite do producer.
- A demo "reserva com o Kafka parado → evento sai quando o Kafka volta" não existe.
- Os consumers continuam deduplicando por `evento_id` ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)), o que já prepara o terreno para o Outbox, que entrega "pelo menos uma vez".

## Referências

- Aula 3 · P2 [00:33:26]: a ordem importa; salvar primeiro na fonte da verdade, depois publicar.
- Aula 3 · P2 [00:36:18]–[00:38:05]: Outbox Pattern e Debezium.
- RICHARDSON, Chris. **Pattern: transactional outbox**. Disponível em: <https://microservices.io/patterns/data/transactional-outbox.html>.
