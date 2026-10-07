# ADR-0004: Decomposição em serviços (containers do C4 nível 2)

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q07](../questoes-abertas.md#q07) · [Q09](../questoes-abertas.md#q09)
- **Afeta no diagrama:** C4 nível 2 inteiro (containers, bancos e setas)

## Contexto

- O sistema está enquadrado no [ADR-0003](0003-enquadramento-plataforma-multi-tenant.md): marketplace multi-tenant, leitura muito maior que escrita, disputa por horário, notificações em massa.
- Heurística do professor: um domínio grande com subdomínios vira container (Aula 1 [01:02:18]). Container do C4 não é container Docker.
- Restrições: 7 pessoas, 3 semanas, "nada mirabolante", tudo o que for desenhado precisa funcionar.

## Opções consideradas

### A. Monolito modular

- **Prós:** mais simples de construir e operar.
- **Contras:** não atende ao trabalho (multiplataforma, 2 linguagens, mensageria entre serviços).

### B. Três serviços: barbearia (cadastro), agendamento e notificação

- **Prós:** mínimo viável; menos coisa para manter funcionando.
- **Contras:** a consulta de disponibilidade fica junto da escrita no agendamento; o CQRS fica só "lite" (pacotes separados) e a escala de leitura não aparece na arquitetura.

### C. Cinco containers de aplicação: BFF + barbearia + agendamento + disponibilidade + notificação

- **Prós:** cada container tem um motivo claro para existir (ver tabela); o CQRS completo aparece no diagrama (agendamento escreve, disponibilidade lê); dá 1 serviço para cada dupla de integrantes, mais infraestrutura.
- **Contras:** mais um serviço e mais um consumer para manter.

### D. Sete ou mais serviços (+ pagamento, avaliações, fidelidade)

- **Prós:** sistema mais completo.
- **Contras:** não cabe em 3 semanas; pagamento traz integração externa que não é avaliada.

## Decisão

**Proposta:** opção C.

| Container | Responsabilidade | Dados próprios | Publica | Consome |
|---|---|---|---|---|
| **bff-gateway** | Ponto de entrada único; valida o JWT (401/403); roteia e compõe respostas para os canais | — | — | — |
| **barbearia-service** | Cadastro de barbearias, profissionais, serviços (duração e preço) e expediente (dias, horários, folgas) | schema `barbearia` | `expediente.alterado` | — |
| **agendamento-service** | Reservar, cancelar e remarcar; garante que não existam dois agendamentos no mesmo horário do profissional (fonte da verdade) | schema `agendamento` | `agendamento.criado`, `agendamento.cancelado` | — |
| **disponibilidade-service** | Responde "quais horários estão livres" (lado de leitura do CQRS); mantém um read model atualizado por eventos | schema `disponibilidade` (read model) | — | `agendamento.*`, `expediente.alterado` |
| **notificacao-service** | Envia confirmação e cancelamento (e lembretes, se entrarem) por um provedor externo de mensagens | schema `notificacao` (histórico, idempotência) | — | `agendamento.*` |

Infraestrutura no mesmo diagrama: **Keycloak** (IdP, externo), **Kafka**, **PostgreSQL** (um schema por serviço, ver [ADR-0011](0011-dados-por-servico.md)) e o **provedor de mensagens** (externo, simulado).

Chamada síncrona entre serviços: `agendamento-service → barbearia-service` para validar o serviço escolhido (duração) e o expediente do profissional no momento da reserva (ver [ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).

**Fora do diagrama** nesta versão: pagamento, avaliações, fidelidade e front-ends ([Q06](../questoes-abertas.md#q06)).

## Consequências

- Cinco pastas em `services/`. Cada serviço tem dono ([Q22](../questoes-abertas.md#q22)).
- O BFF é único para todos os canais nesta versão. Separar um BFF por canal (app do cliente × painel da barbearia) fica como evolução para a Aula 5 ([Q09](../questoes-abertas.md#q09)).
- O agendamento depende do barbearia-service em tempo de reserva. Isso exige timeout e circuit breaker (Aula 5).

## Perguntas para o grupo

- Cinco containers cabem no prazo, ou começamos com B e promovemos a disponibilidade a serviço só se sobrar tempo?
- Lembretes (véspera e 1 h antes) entram? Eles exigem um agendador de tarefas ([Q17](../questoes-abertas.md#q17)).
- Pagamento de sinal entra como sistema externo simulado ([Q05](../questoes-abertas.md#q05))?

## Referências

- Aula 1 [01:02:18]–[01:08:52]: containers do PizzaExpress; um domínio grande com subdomínios vira container.
- Aula 1 [01:12:15]: cuidado com orquestração e regra de negócio no BFF; o serviço deve ter autonomia para consultar outro serviço.
- RICHARDSON, Chris. **Pattern: decompose by subdomain**. Disponível em: <https://microservices.io/patterns/decomposition/decompose-by-subdomain.html>.
