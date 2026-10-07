# ADR-0006: Comunicação síncrona, assíncrona e o broker de eventos (Kafka)

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q10](../questoes-abertas.md#q10) · [Q11](../questoes-abertas.md#q11)
- **Afeta no diagrama:** C4 nível 2 (todas as setas e seus protocolos; o container do broker)

## Contexto

- O trabalho exige mensageria (Kafka, MQTT…) ou a justificativa para tudo ser síncrono.
- Pela volumetria do [ADR-0003](0003-enquadramento-plataforma-multi-tenant.md), cada agendamento gera de 1 a 3 mensagens para um provedor externo com limite de taxa (o caso do erro 429 da Aula 3), e o read model de disponibilidade ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)) precisa saber de cada reserva e cancelamento.
- Algumas interações precisam de resposta imediata: o cliente quer saber na hora se conseguiu o horário.

## Opções consideradas (broker)

### A. Apache Kafka

- **Prós:** o worker **puxa** a mensagem quando está livre (pull), o que protege contra rate limit; partições por chave preservam a ordem dos eventos de um mesmo profissional; a **retenção permite reprocessar** e reconstruir o read model do CQRS; consumer groups dão a cada serviço sua cópia; é o que o professor demonstra e já está no ambiente do PizzaExpress (com Kafka UI e métricas).
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

**Proposta:** opção A (Kafka) para eventos e REST para o que precisa de resposta imediata.

### O que é síncrono (REST/HTTP)

| De → Para | Para quê | Por que síncrono |
|---|---|---|
| Cliente/apps → bff-gateway | Todas as operações (HTTPS + JWT) | Entrada única |
| bff-gateway → serviços | Encaminhar comandos e consultas | O usuário espera a resposta |
| agendamento → barbearia-service | Validar serviço (duração) e expediente do profissional na hora de reservar | A reserva não pode usar um dado desatualizado de expediente; com timeout e circuit breaker |

### O que é assíncrono (Kafka)

| Tópico | Producer | Consumers | Chave da partição |
|---|---|---|---|
| `agendamento.criado` | agendamento-service | disponibilidade-service, notificacao-service | `profissional_id` |
| `agendamento.cancelado` | agendamento-service | disponibilidade-service, notificacao-service | `profissional_id` |
| `expediente.alterado` | barbearia-service | disponibilidade-service | `profissional_id` |

- **Chave por profissional:** todos os eventos de um profissional caem na mesma partição, então o read model os aplica em ordem (um cancelamento nunca chega antes da criação).
- **Envelope dos eventos:** `evento_id`, `tipo`, `versao`, `ocorrido_em`, `barbearia_id` e `payload`. Contratos versionados em `contracts/` (AsyncAPI é o desejável da Aula 5).
- **Entrega "pelo menos uma vez":** consumers idempotentes (guardam o `evento_id` já processado). Mensagem que falha N vezes vai para `<tópico>.dlq`.
- **Remarcar** é cancelar + criar, sem tópico próprio, nesta versão.

## Consequências

- A reserva responde ao cliente sem esperar a notificação nem o read model (consistência eventual: a grade de horários pode demorar alguns milissegundos para refletir a reserva).
- Precisamos garantir que o evento seja publicado depois do commit: [ADR-0012](0012-garantia-de-publicacao-outbox.md) (Outbox).
- A demo mostra a mensagem no Kafka UI e o consumer processando.

## Perguntas para o grupo

- Kafka mesmo, ou alguém quer defender RabbitMQ?
- O agendamento consulta o barbearia-service de forma síncrona (proposta) ou mantém uma cópia local do expediente alimentada por eventos (mais autônomo, mais trabalho)?
- Nomes dos tópicos em português (`agendamento.criado`) ou inglês (`appointment.created`) ([Q23](../questoes-abertas.md#q23))?

## Referências

- Aula 3 · P2 [00:40:55]: MQTT empurra, Kafka puxa; partições e consumer groups; só com volumetria alta.
- Aula 3 · P2 [00:14:22]–[00:18:04]: tópicos por grupo e um consumer por tópico.
- Aula 1 [00:36:55]: eixo de comunicação (REST síncrono + eventos assíncronos).
- NARKHEDE, Neha; SHAPIRA, Gwen; PALINO, Todd. **Kafka**: the definitive guide. O'Reilly, 2017.
