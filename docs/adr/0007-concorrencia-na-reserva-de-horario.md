# ADR-0007: Concorrência na reserva de horário (lock)

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q14](../questoes-abertas.md#q14)
- **Afeta no diagrama:** C4 nível 2 (agendamento-service → PostgreSQL); C4 nível 3 do agendamento-service

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

**Proposta:** opção **C** como garantia final, com duas camadas:

1. O aggregate de domínio valida as regras (dentro do expediente, horário no futuro, serviço existe) e consulta a **fonte da verdade**, nunca o read model.
2. O INSERT conta com a constraint de exclusão; se violada, o serviço responde **409 Conflict** com uma mensagem amigável ("horário acabou de ser reservado, escolha outro").
3. Mudanças de estado do mesmo agendamento (cancelar × concluir ao mesmo tempo) usam lock otimista (`@Version`) no aggregate `Agendamento`.

A opção D fica registrada como **evolução** para quando a escrita crescer a ponto de a disputa no banco virar gargalo.

## Consequências

- Demo forte e simples: disparar duas reservas simultâneas para o mesmo horário (script com curl em paralelo) → uma recebe **201**, a outra **409**.
- A justificativa na apresentação fica: "pouca escrita com muita disputa → lock no banco; muita leitura → CQRS".
- O banco do agendamento precisa da extensão `btree_gist` (vem no PostgreSQL oficial).
- O agendamento-service é o único que escreve em `agendamento`; os outros serviços só sabem das reservas por evento.

## Perguntas para o grupo

- Constraint de exclusão (C) ou lock otimista puro (B)? Alguém prefere defender a serialização pelo Kafka (D), que é a abordagem da aula?
- Precisamos de pré-reserva com expiração (E) na demo, ou basta a reserva direta?

## Referências

- Aula 3 · P2 [00:05:44]: concorrência; `synchronized` não resolve com várias instâncias.
- Aula 3 · P2 [00:14:22]–[00:18:04]: escalar o command com tópicos e um consumer por tópico.
- Aula 3 · P2 [00:20:40]: quando lock basta e quando trava o banco.
- POSTGRESQL. **Exclusion constraints**. Disponível em: <https://www.postgresql.org/docs/16/ddl-constraints.html#DDL-CONSTRAINTS-EXCLUSION>.
- KLEPPMANN, Martin. **Designing data-intensive applications**. O'Reilly, 2017. Capítulo 7 (transações, *write skew*).
