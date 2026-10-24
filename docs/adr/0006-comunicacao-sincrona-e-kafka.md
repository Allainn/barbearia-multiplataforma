# ADR-0006: Comunicação síncrona, assíncrona e o broker de eventos (Kafka)

- **Status:** Aceito
- **Data:** 22/10/2026
- **Questão:** [Q10](../questoes-abertas.md#q10) · [Q11](../questoes-abertas.md#q11)
- **Afeta no diagrama:** C4 nível 2 (todas as setas e seus protocolos; o container do broker)

## Contexto

- O trabalho exige mensageria (Kafka, MQTT…) ou a justificativa para tudo ser síncrono.
- Pela volumetria do [ADR-0003](0003-enquadramento-plataforma-multi-tenant.md), cada agendamento gera de 1 a 3 mensagens para um provedor externo com limite de taxa (o caso do erro 429 da Aula 3), e o read model de disponibilidade ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)) precisa saber de cada reserva e cancelamento.
- Algumas interações precisam de resposta imediata: o cliente quer saber na hora se conseguiu o horário.

## Opções consideradas (broker)

### A. Apache Kafka

- **Prós:** o worker **puxa** a mensagem quando está livre (pull), o que protege contra rate limit; partições por chave preservam a ordem dos eventos de um mesmo profissional dentro de cada tópico; a **retenção permite reprocessar** e reconstruir o read model do CQRS; consumer groups dão a cada serviço sua cópia; é o que o professor demonstra e já está no ambiente do PizzaExpress (com Kafka UI e métricas).
- **Contras:** mais pesado para rodar localmente; o grupo precisa entender partição, offset e DLQ.

### B. RabbitMQ

- **Prós:** filas e roteamento simples; mais leve.
- **Contras:** sem replay nativo (a mensagem consumida sai da fila), o que atrapalha reconstruir o read model; não temos exemplo pronto das aulas.

### C. MQTT

- **Prós:** muito leve, bom para IoT e dispositivos móveis.
- **Contras:** empurra (push) para o worker; se a API externa estiver lenta, o worker não dá conta (Aula 3 · P2 [00:40:55]). Não é o caso de uso dele.

### D. Tudo síncrono (REST entre serviços)

- **Prós:** mais simples de depurar.
- **Contras:** a reserva ficaria presa ao provedor de mensagens (se ele cair ou devolver 429, a reserva falha); o read model teria que ser atualizado por chamada direta, acoplando os serviços.

## Decisão

**Kafka (opção A) para os eventos e REST síncrono para o que precisa de resposta imediata.**

### O que é síncrono (REST/HTTP)

| De → Para | Para quê | Por que síncrono |
|---|---|---|
| Cliente → bff-gateway | Todas as operações (HTTP + JWT) | Entrada única; o BFF valida o token ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)) |
| bff-gateway → barbearia, agendamento e disponibilidade | Encaminhar comandos e consultas, com o `sub` do token no header `X-User-ID` | O usuário espera a resposta (201, 409, lista de horários) |

Não há chamada síncrona entre os serviços. O agendamento usa os IDs fixos de barbearia, profissional e serviço sem consultar o barbearia-service.

### O que é assíncrono (Kafka)

| Tópico | Partições | Chave | Producer | Consumers (group id) |
|---|---|---|---|---|
| `agendamento.criado` | 3 | `profissional_id` | agendamento-service | `notificacao-service`, `disponibilidade-service` |
| `agendamento.cancelado` | 3 | `profissional_id` | agendamento-service | `notificacao-service`, `disponibilidade-service` |

- **Criação dos tópicos:** o serviço `kafka-init` do `infra/docker-compose.yml` cria os dois tópicos com 3 partições antes de qualquer consumer subir.
- **Chave por profissional:** dentro de cada tópico, todos os eventos de um profissional caem na mesma partição e são consumidos na ordem em que foram publicados. O Kafka não garante ordem entre tópicos diferentes: se o consumer atrasar, um `agendamento.cancelado` pode ser processado antes do `agendamento.criado` do mesmo agendamento. Cada consumer trata isso do seu jeito:
  - **notificacao-service:** é inofensivo; o cliente recebe as duas mensagens, só que fora de ordem.
  - **disponibilidade-service:** o cancelado não apaga a linha, marca `cancelado = true` (tombstone). Se ele chegar antes, o criado que vem depois não reativa o horário ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)).
- **Consumer groups:** cada serviço consumidor tem o próprio group id e recebe a sua cópia de cada evento.
- **Envelope:** JSON em UTF-8 com `evento_id`, `tipo`, `versao`, `ocorrido_em`, `barbearia_id` e `payload` (`agendamento_id`, `profissional_id`, `cliente_id`, `inicio`, `fim`). O cancelado muda só o `tipo`.
- **Entrega "pelo menos uma vez" com consumers idempotentes.** Nos dois consumers o auto-commit está desligado: o offset é confirmado só depois de processar cada mensagem. Se o serviço cair no meio, a mensagem em andamento é lida de novo ao voltar, então a mesma mensagem pode chegar duas vezes. Cada consumer aguenta isso no próprio banco:
  - **notificacao-service:** a tabela `notificacao.envio` tem `evento_id UNIQUE`, e a gravação usa `INSERT ... ON CONFLICT (evento_id) DO NOTHING`. Se nenhuma linha entrou, o evento é repetido: o serviço registra `evento <evento_id> repetido, ignorado` e não envia a mensagem de novo. O envio só acontece depois da gravação.
  - **disponibilidade-service:** `INSERT ... ON CONFLICT (agendamento_id) DO NOTHING` no criado e `INSERT ... ON CONFLICT (agendamento_id) DO UPDATE SET cancelado = true` no cancelado ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)).
- **Trace pelo Kafka:** o agendamento-service injeta o contexto de trace W3C nos headers da mensagem, e os consumers o extraem ao abrir o span `kafka consume <tópico>`. Assim, o consumo e o que vem depois dele ficam no mesmo trace da reserva.
- **Provedor de mensagens simulado:** o notificacao-service escreve `mensagem enviada para <cliente_id>: <texto>` no log, no lugar da chamada ao provedor externo. O envio fica dentro de um span `CLIENT` (`provedor-mensagens enviar`, com `peer.service=provedor-mensagens`), então a integração externa aparece no fim do trace da reserva no Tempo e como nó no service graph.
- **Falhas nos consumers** (o mesmo tratamento nos dois): se o Kafka não responder quando o serviço sobe, o consumer tenta conectar de novo a cada 5 s, em vez de parar. O parse do JSON fica dentro do tratamento de erro do loop: uma mensagem mal formada gera log de erro, e o consumo segue. Falha de conexão com o Postgres é tentada de novo até 3 vezes; se persistir, o offset volta e a mensagem é relida 5 s depois.

**Ficaram fora por prazo:** a DLQ (`<tópico>.dlq`) para mensagens que falham várias vezes, o tópico `expediente.alterado` (o expediente é fixo, das 09:00 às 18:00) e o contrato em AsyncAPI. O contrato dos eventos está em `docs/tarefas.md`.

## Consequências

- A reserva responde ao cliente sem esperar a notificação nem o read model. A consistência é eventual: a grade de horários e a notificação podem demorar alguns milissegundos para refletir a reserva.
- Se o provedor de mensagens cair ou ficar lento, só o consumer atrasa; a reserva não é afetada.
- Com o commit manual, uma falha de banco não perde a mensagem, mas segura a partição: enquanto o Postgres estiver fora, o consumer relê a mesma mensagem a cada 5 s, e as seguintes daquela partição esperam. Quando o banco volta, o consumo segue de onde parou.
- Sem DLQ, uma mensagem com conteúdo inválido fica só no log de erro e é descartada. A retenção do Kafka permite reprocessar à mão, voltando o offset do group.
- O evento é publicado logo depois do commit, sem Outbox ([ADR-0012](0012-garantia-de-publicacao-outbox.md), rejeitado por prazo). Se o agendamento cair entre o commit e o envio, o evento se perde.
- A demo mostra a mensagem no Kafka UI, o log do `notificacao-service` e o horário sumindo da consulta de disponibilidade.

## Referências

- Aula 3 · P2 [00:40:55]: MQTT empurra, Kafka puxa; partições e consumer groups; só com volumetria alta.
- Aula 3 · P2 [00:14:22]–[00:18:04]: tópicos por grupo e um consumer por tópico.
- Aula 1 [00:36:55]: eixo de comunicação (REST síncrono + eventos assíncronos).
- NARKHEDE, Neha; SHAPIRA, Gwen; PALINO, Todd. **Kafka**: the definitive guide. O'Reilly, 2017.
