# ADR-0008: CQRS na consulta de disponibilidade

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q15](../questoes-abertas.md#q15)
- **Afeta no diagrama:** C4 nível 2 (disponibilidade-service, seu banco e as setas vindas do Kafka)

## Contexto

- "Quais horários estão livres?" é a operação mais frequente do sistema: ~50 consultas para cada reserva, com rajadas de ~1.300 req/s ([ADR-0003](0003-enquadramento-plataforma-multi-tenant.md)).
- Calcular a disponibilidade é caro: expediente do profissional − folgas e bloqueios − agendamentos confirmados, para cada profissional da barbearia, ajustado à duração do serviço escolhido.
- Se esse cálculo rodar nas mesmas tabelas em que o agendamento escreve com lock ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)), as leituras disputam com as escritas justamente no pico. É o cenário da Aula 3: escrita e consulta na mesma tabela travam o banco.

## Opções consideradas

### A. Sem CQRS: calcular na hora, no agendamento-service, a partir da fonte da verdade

- **Prós:** sempre consistente; nada para sincronizar.
- **Contras:** a leitura pesada cai no banco que tem o lock; não dá para escalar leitura e escrita separadamente.

### B. CQRS lite: commands e queries em pacotes separados, mesmo serviço e mesmo banco

Como o `order-service` do PizzaExpress.

- **Prós:** organiza o código; pouco custo.
- **Contras:** separa só no código; a carga continua no mesmo banco e no mesmo processo.

### C. CQRS completo: disponibilidade-service separado, com read model próprio atualizado por eventos

Como os scaffolds `cqrs-command` e `cqrs-query` da Aula 3.

- **Prós:** a leitura escala sozinha (N réplicas, banco próprio); o read model já guarda os horários livres prontos, então a consulta é um SELECT simples; reconstruível a qualquer momento reprocessando os tópicos do Kafka.
- **Contras:** consistência eventual (a grade pode mostrar por alguns milissegundos um horário que acabou de ser reservado); mais um serviço e um consumer.

### D. Cache (Redis) na frente do cálculo da opção A

- **Prós:** rápido de adicionar.
- **Contras:** invalidar o cache a cada reserva ou cancelamento é o problema difícil; cache frio no pico cai de novo no banco do agendamento.

## Decisão

**Proposta:** opção **C**.

- **Write side:** agendamento-service (fonte da verdade, schema `agendamento`).
- **Read side:** disponibilidade-service, schema `disponibilidade`, com uma tabela por profissional e dia já com os intervalos livres (ex.: `horario_livre(barbearia_id, profissional_id, data, inicio, fim)`).
- **Sincronização:** consome `agendamento.criado`, `agendamento.cancelado` e `expediente.alterado` ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).
- **Regra de ouro (Aula 3):** o command **nunca** decide com base na view. Se a grade estiver desatualizada e o cliente escolher um horário já ocupado, o agendamento responde 409 ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)) e o cliente escolhe outro.

## Consequências

- Na apresentação: "lock na escrita, CQRS na leitura", cada um justificado por um número diferente da volumetria.
- A demo mostra a reserva → evento no Kafka → horário some da consulta de disponibilidade.
- Precisamos de um jeito de popular o read model do zero (reprocessar os tópicos desde o início ou um endpoint de rebuild).
- Se o tempo apertar, o recuo planejado é a opção B (CQRS lite dentro do agendamento), registrado num ADR novo.

## Perguntas para o grupo

- CQRS completo (C) cabe no prazo, ou começamos com B?
- O read model fica no PostgreSQL (proposta, menos infraestrutura) ou no Redis ([Q12](../questoes-abertas.md#q12))?

## Referências

- Aula 3 · P2 [00:00:04]–[00:03:48]: CQRS, command × query; CQRS lite no `order-service`.
- Aula 3 · P2 [00:24:14]: command grava na fonte da verdade, publica, consumer atualiza a view; o command nunca decide pela view.
- Aula 3 · P3 [00:01:26]: a view não precisa espelhar a tabela; uma tabela de command alimenta várias views.
- FOWLER, Martin. **CQRS**. Disponível em: <https://martinfowler.com/bliki/CQRS.html>.
- Código: `pizzaexpress-encontro-3/scaffolds/scaffold-cqrs-command-java/` e `scaffold-cqrs-query-java/`.
