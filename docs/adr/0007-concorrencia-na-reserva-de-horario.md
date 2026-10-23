# ADR-0007: Concorrência na reserva de horário (lock)

- **Status:** Aceito
- **Data:** 21/10/2026
- **Questão:** [Q14](../questoes-abertas.md#q14)
- **Afeta no diagrama:** C4 nível 2 (agendamento-service → PostgreSQL)
- **Aprovações:** no PR do agendamento-service

## Contexto

- O risco central do domínio é o **double booking**: dois clientes reservam o mesmo profissional no mesmo horário. Com várias instâncias do agendamento-service atrás de um load balancer, `synchronized` ou um lock em memória não resolvem (Aula 3 · P2 [00:05:44]).
- Os serviços têm durações diferentes (corte 30 min, corte + barba 50 min), então o conflito é de **sobreposição de intervalos**, não só de "mesmo horário de início".
- Pela volumetria do [ADR-0003](0003-enquadramento-plataforma-multi-tenant.md), a escrita é baixa em volume (~3 reservas/s no pico), mas tem **rajadas de disputa** pelo mesmo horário (sexta 18h, abertura da agenda).
- O trabalho pede "CQRS **ou** lock, com justificativa". Este ADR trata da escrita; a leitura está no [ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md).

## Opções consideradas

### A. Lock pessimista (`SELECT … FOR UPDATE` na agenda do profissional no dia)

- **Prós:** fácil de entender; funciona com N instâncias porque quem segura o lock é o banco.
- **Contras:** serializa todas as reservas do profissional no dia, mesmo em horários diferentes; risco de deadlock se a ordem dos locks variar; a transação fica aberta durante a validação.

### B. Lock otimista (coluna `versao` na agenda do profissional no dia)

- **Prós:** não bloqueia; o conflito é detectado no commit e vira 409.
- **Contras:** precisa de um registro "agenda do dia" para versionar; em rajada de disputa, muitas tentativas falham e são refeitas.

### C. Constraint de exclusão no PostgreSQL

`EXCLUDE USING gist (profissional_id WITH =, tstzrange(inicio, fim) WITH &&) WHERE (status = 'CONFIRMADO')`

- **Prós:** o **banco garante** que não existem dois intervalos sobrepostos para o mesmo profissional, qualquer que seja o número de instâncias ou o caminho do código; trata durações diferentes; só conflita quem realmente disputa o mesmo intervalo; a violação vira 409 Conflict.
- **Contras:** recurso específico do PostgreSQL (extensão `btree_gist`); a regra fica no banco, não no código de domínio, então o domínio também valida antes (defesa em profundidade).

### D. Serializar os comandos pelo Kafka (tópico particionado por profissional)

Abordagem da Aula 3: a API publica o comando, um consumer por partição grava em ordem e ninguém escreve ao mesmo tempo no mesmo profissional.

- **Prós:** escala a escrita sem lock no banco; é o padrão mostrado em aula para alta volumetria.
- **Contras:** a reserva vira assíncrona (202 Accepted + consulta de status), o que complica a experiência e a demo; nosso volume de escrita (~3/s) não exige isso.

### E. Lock distribuído no Redis (`SET NX PX`), segurando o horário por alguns minutos

- **Prós:** permite "pré-reserva" com expiração enquanto o cliente confirma.
- **Contras:** mais um componente (Redis) só para isso; o lock pode expirar no meio da operação; ainda precisa de garantia no banco.

## Decisão

Opção **C**: constraint de exclusão no PostgreSQL, com 409 para quem perde a disputa.

Na votação da [#14](https://github.com/Allainn/barbearia-multiplataforma/issues/14), em 07/10, o grupo tinha escolhido a opção D. Em 21/10, a uma semana da apresentação, o [roadmap](../roadmap.md) cortou tudo o que custava tempo, e a D saiu. Ela exigia um tópico de comando, um consumer de comandos, a resposta 202 e uma rota de consulta de status. A C cabe numa constraint e num `ON CONFLICT DO NOTHING`, e entrega a mesma garantia para o nosso volume (~3 reservas/s no pico).

Como foi implementado, em `services/agendamento-service`:

1. A tabela `agendamento.agendamento` tem a constraint `sem_sobreposicao`: `EXCLUDE USING gist (profissional_id WITH =, tstzrange(inicio, fim) WITH &&) WHERE (status = 'CONFIRMADO')` (`MigrationRunner`). A extensão `btree_gist` vem do SQL de criação do banco.
2. O aggregate `Agendamento` valida o que não depende de disputa: `fim` depois de `inicio` e `inicio` no futuro. Se falhar, a resposta é 422.
3. `POST /agendamentos` faz um único `INSERT ... ON CONFLICT DO NOTHING`, sem leitura prévia nem lock na aplicação. Sem alvo no `ON CONFLICT`, o PostgreSQL usa a constraint `sem_sobreposicao` como árbitro: se o intervalo se sobrepõe a um agendamento confirmado, nenhuma linha entra, o `PostgresAgendamentoRepository` lança `HorarioIndisponivelException`, e a resposta é **409** com `{"detail": "Horário indisponível para este profissional"}`. Nesse caso nenhum evento é publicado.
4. O `ON CONFLICT` evita um deadlock. Num INSERT comum, dois pedidos sobrepostos ao mesmo tempo gravam cada um sua entrada no índice e esperam a transação do outro, e o PostgreSQL aborta um deles com deadlock (`40P01`) em vez de `23P01`. A primeira versão repetia o INSERT abortado até 3 vezes: com 2 pedidos funcionava, mas com 5, 10 ou 20 pedidos simultâneos os perdedores travavam uns aos outros e recebiam 500 depois de 13 a 59 s. Com `ON CONFLICT`, a inserção é especulativa: quem encontra outra inserção em andamento desfaz a sua e espera o commit da outra, sem deadlock. Nos testes, de 2 a 20 pedidos simultâneos no mesmo horário deram sempre um 201 e o resto 409, em menos de 25 ms.
5. `DELETE /agendamentos/{id}` muda o status para `CANCELADO` com `UPDATE ... WHERE id = ? AND status <> 'CANCELADO'`. Pelo `WHERE` da constraint, o horário fica livre na hora. O evento `agendamento.cancelado` só sai se o UPDATE mudou a linha: cancelar de novo devolve 204 sem publicar outro evento, mesmo quando dois DELETEs chegam ao mesmo tempo.
6. A reserva é decidida só pela fonte da verdade (`agendamento.agendamento`), nunca pelo read model da disponibilidade ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)).

Ficou fora: a validação de expediente e de serviço no barbearia-service (a chamada REST saiu do escopo) e o lock otimista com `@Version`, porque não existe a operação "concluir" para concorrer com o cancelamento. Dois cancelamentos simultâneos já são resolvidos pelo UPDATE condicional do item 5.

A opção D fica registrada como evolução, para quando a disputa no banco virar gargalo.

## Consequências

- Demo: `scripts/disputa.sh` dispara duas reservas iguais ao mesmo tempo, uma recebe **201** e a outra **409**. Direto no serviço ou pelo BFF, com `TOKEN`.
- A justificativa na apresentação: "pouca escrita, mas com disputa pelo mesmo horário → lock no banco; muita leitura → CQRS".
- A garantia vale com qualquer número de instâncias do agendamento-service, porque quem decide é o banco.
- Quem perde a disputa espera só o commit de quem ganhou e recebe o 409 em milissegundos. Todos os pedidos pelo mesmo profissional e horário passam por esse ponto do banco; se a disputa crescer a ponto de virar gargalo, a opção D tira essa espera do banco.
- A regra fica no banco, não no código de domínio. Quem ler só o Java não vê a regra de sobreposição; o comentário no `Agendamento` e no `MigrationRunner` aponta para ela.
- O agendamento-service é o único que escreve em `agendamento`; os outros serviços só sabem das reservas por evento ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).

## Referências

- Aula 3 · P2 [00:05:44]: concorrência; `synchronized` não resolve com várias instâncias.
- Aula 3 · P2 [00:14:22]–[00:18:04]: escalar o command com tópicos e um consumer por tópico.
- Aula 3 · P2 [00:20:40]: quando lock basta e quando trava o banco.
- POSTGRESQL. **Exclusion constraints**. Disponível em: <https://www.postgresql.org/docs/16/ddl-constraints.html#DDL-CONSTRAINTS-EXCLUSION>.
- POSTGRESQL. **INSERT: ON CONFLICT clause**. Disponível em: <https://www.postgresql.org/docs/16/sql-insert.html#SQL-ON-CONFLICT>. O deadlock entre INSERTs comuns e a inserção especulativa que o evita estão descritos no comentário de `src/backend/executor/execIndexing.c`.
- KLEPPMANN, Martin. **Designing data-intensive applications**. O'Reilly, 2017. Capítulo 7 (transações, *write skew*).
