# ADR-0008: CQRS na consulta de disponibilidade

- **Status:** Aceito
- **Data:** 23/10/2026
- **Questão:** [Q15](../questoes-abertas.md#q15)
- **Afeta no diagrama:** C4 nível 2 (disponibilidade-service, seu banco e as setas vindas do Kafka)
- **Aprovações:** no PR do disponibilidade-service

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

Opção **C**: CQRS completo, com o read model num serviço separado, atualizado pelos eventos do Kafka.

Como foi implementado, em `services/disponibilidade-service` (Python, FastAPI, porta 8003):

1. **Write side:** agendamento-service, fonte da verdade (schema `agendamento`). **Read side:** disponibilidade-service, com schema e usuário próprios (`disponibilidade`, `disponibilidade_svc`) no mesmo PostgreSQL ([ADR-0011](0011-dados-por-servico.md)). O serviço não publica nada e não chama nenhum outro.
2. **Read model:** a tabela `disponibilidade.horario_ocupado (agendamento_id, barbearia_id, profissional_id, inicio, fim, cancelado)`, com índice em `(profissional_id, inicio)`. Ela guarda os horários **ocupados**, e os cancelados ficam marcados com `cancelado = true` (item 3); não guarda a grade pronta. Não é uma cópia da tabela `agendamento`: não tem status nem cliente, só o que a consulta precisa.
3. **Sincronização:** um consumer (`group_id = disponibilidade-service`) lê `agendamento.criado` e `agendamento.cancelado` (chave `profissional_id`, 3 partições, [ADR-0006](0006-comunicacao-sincrona-e-kafka.md)). `criado` faz `INSERT ... ON CONFLICT (agendamento_id) DO NOTHING`. `cancelado` grava a linha já marcada como cancelada (`INSERT ... ON CONFLICT (agendamento_id) DO UPDATE SET cancelado = true`) em vez de apagar, e a consulta ignora as linhas canceladas. A chave por profissional garante a ordem só dentro de cada tópico; entre `criado` e `cancelado`, que são tópicos diferentes, não há ordem garantida. Com a linha cancelada guardada (um *tombstone*), um `cancelado` que chegue antes do `criado` não deixa o horário ocupado: o `criado` que vem depois cai no `ON CONFLICT` e não muda nada. Como a entrega é "pelo menos uma vez", receber a mesma mensagem duas vezes também não muda o resultado. O offset só é commitado depois de aplicar o evento, e, se o Kafka estiver fora quando o serviço sobe, o consumer tenta conectar de novo a cada 5 s.
4. **Consulta:** `GET /disponibilidade?profissional_id=...&data=AAAA-MM-DD` monta, a cada chamada, a grade fixa das 09:00 às 18:00 em `America/Sao_Paulo` (18 blocos de 30 min) e remove os blocos que se sobrepõem a algum horário ocupado (`inicio < fim_do_bloco` e `fim > inicio_do_bloco`). É um único SELECT indexado por profissional. Os blocos saem em ordem e com offset `-03:00`; parâmetro ausente ou inválido devolve 422.
5. **Regra de ouro (Aula 3):** o command **nunca** decide com base na view. Se a grade estiver desatualizada e o cliente escolher um horário já ocupado, o agendamento responde 409 ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)) e o cliente escolhe outro.
6. **Consistência eventual:** entre o commit da reserva e o consumer aplicar o evento, a grade pode mostrar por alguns milissegundos um horário que acabou de ser reservado. Se o consumer ficar parado, a grade fica desatualizada, mas o agendamento continua correto.

Ficou fora, por prazo:

- **Expediente configurável.** A grade é fixa no código, então não há tabela de horários livres por profissional e dia (como a proposta inicial previa) nem o evento `expediente.alterado`. Guardar só os horários ocupados já resolve o que a demo mostra e evita ter de recalcular a tabela inteira quando o expediente mudar.
- **Folgas, bloqueios e duração do serviço.** A consulta devolve blocos de 30 min, não ajusta à duração do serviço escolhido.
- **Rebuild do read model.** Como o consumer lê com `auto_offset_reset = earliest` e o grupo é novo, subir o serviço com o banco vazio reprocessa os tópicos desde o início, o que reconstrói a tabela. Por causa do tombstone, a ordem em que os dois tópicos são relidos não importa. Não há endpoint de rebuild.

## Consequências

- Na apresentação: "lock na escrita, CQRS na leitura", cada um justificado por um número diferente da volumetria.
- A demo mostra a reserva → evento no Kafka → horário some da consulta de disponibilidade → cancelamento → horário volta.
- A leitura (~50 consultas por reserva) escala sozinha: dá para subir mais réplicas do disponibilidade-service sem tocar no banco do agendamento, que tem a constraint de exclusão.
- Mais um serviço, um consumer e uma tabela para manter, em troca de tirar a leitura pesada do banco com lock.
- Se o Postgres estiver fora, o consumer não commita, volta o offset e relê a mensagem a cada 5 s. Uma mensagem que não dá para processar (JSON inválido, campo ausente) é registrada no log e descartada; não há DLQ ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)). Uma mensagem descartada deixa um horário errado na grade até o próximo evento do mesmo agendamento.
- A tabela não encolhe: os cancelamentos ficam como linhas marcadas. No volume da demo isso não pesa; em produção, uma limpeza periódica das linhas canceladas antigas resolveria.
- O recuo planejado, se o tempo apertasse, era a opção B (CQRS lite dentro do agendamento). Não foi preciso.

## Referências

- Aula 3 · P2 [00:00:04]–[00:03:48]: CQRS, command × query; CQRS lite no `order-service`.
- Aula 3 · P2 [00:24:14]: command grava na fonte da verdade, publica, consumer atualiza a view; o command nunca decide pela view.
- Aula 3 · P3 [00:01:26]: a view não precisa espelhar a tabela; uma tabela de command alimenta várias views.
- FOWLER, Martin. **CQRS**. Disponível em: <https://martinfowler.com/bliki/CQRS.html>.
- Código: `pizzaexpress-encontro-3/scaffolds/scaffold-cqrs-command-java/` e `scaffold-cqrs-query-java/`.
