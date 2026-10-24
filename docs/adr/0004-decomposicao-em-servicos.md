# ADR-0004: Decomposição em serviços (containers do C4 nível 2)

- **Status:** Aceito
- **Data:** 24/10/2026
- **Questão:** [Q06](../questoes-abertas.md#q06) · [Q07](../questoes-abertas.md#q07) · [Q09](../questoes-abertas.md#q09) · [Q17](../questoes-abertas.md#q17)
- **Afeta no diagrama:** C4 nível 2 inteiro (containers, bancos e setas)

## Contexto

- O sistema está enquadrado no [ADR-0003](0003-enquadramento-plataforma-multi-tenant.md): marketplace multi-tenant, leitura cerca de 50 vezes maior que a escrita, disputa pelo mesmo horário e mensagens enviadas por um provedor externo com limite de taxa.
- Heurística do professor: um domínio grande com subdomínios vira container (Aula 1 [01:02:18]). Container do C4 não é container Docker.
- Na Aula 5 [00:04:33], o professor pediu que a apresentação explique por que os domínios foram divididos assim e por que microsserviços.
- Restrições: 7 pessoas, uma semana de implementação depois do roadmap (21 a 28/10), e tudo o que está desenhado precisa funcionar.

## Opções consideradas

### A. Monolito modular

- **Prós:** mais simples de construir e operar.
- **Contras:** não atende ao trabalho (multiplataforma, 2 linguagens, mensageria entre serviços).

### B. Três serviços: barbearia (cadastro), agendamento e notificação

- **Prós:** mínimo viável; menos coisa para manter funcionando.
- **Contras:** a consulta de disponibilidade fica junto da escrita no agendamento; o CQRS fica só "lite" (pacotes separados) e a escala de leitura não aparece na arquitetura.

### C. Cinco containers de aplicação: BFF + barbearia + agendamento + disponibilidade + notificação

- **Prós:** cada container tem um motivo claro para existir; o CQRS completo aparece no diagrama (agendamento escreve, disponibilidade lê); cada container tem um dono.
- **Contras:** mais um serviço e mais um consumer para manter.

### D. Sete ou mais serviços (+ pagamento, avaliações, fidelidade)

- **Prós:** sistema mais completo.
- **Contras:** não cabe no prazo; pagamento traz uma integração externa que não é avaliada.

## Decisão

Opção **C**, votada na Q07: cinco containers de aplicação, com um BFF único para todos os canais (votado na Q09).

| Container | Responsabilidade | Dados próprios | Publica | Consome | Dono |
|---|---|---|---|---|---|
| **bff-gateway** | Entrada única: valida o JWT (401/403) e repassa o `sub` do token no header `X-User-ID`; não tem regra de negócio | — | — | — | Evandro |
| **barbearia-service** | Cadastro de barbearias, profissionais e serviços (duração e preço); cria os dados fixos da demo ao subir | schema `barbearia` | — | — | Guilherme |
| **agendamento-service** | Reserva e cancela; é a fonte da verdade da agenda, com a constraint de exclusão que impede dois agendamentos sobrepostos do mesmo profissional | schema `agendamento` | `agendamento.criado`, `agendamento.cancelado` | — | Pedro |
| **disponibilidade-service** | Responde os horários livres de um profissional num dia (lado de leitura do CQRS), com um read model atualizado pelos eventos | schema `disponibilidade` | — | os dois tópicos | Gabriel |
| **notificacao-service** | Manda a confirmação e o cancelamento ao provedor de mensagens (simulado), uma vez por evento | schema `notificacao` | — | os dois tópicos | Daniel |

Infraestrutura no mesmo diagrama: **Keycloak** (IdP, externo), **Kafka**, **PostgreSQL** (um schema por serviço, [ADR-0011](0011-dados-por-servico.md)) e o **provedor de mensagens** (externo, simulado). A infraestrutura e o pipeline são do João.

### Por que cada fronteira

- **BFF separado dos serviços:** a segurança e o roteamento ficam na borda, num lugar só. Os serviços não conhecem o Keycloak e não repetem a validação do token ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)). Como o professor alertou sobre regra de negócio no BFF (Aula 1 [01:12:15]), ele só valida e encaminha.
- **barbearia × agendamento:** os dados mudam em ritmos diferentes. O cadastro muda pouco e não tem disputa. A agenda recebe a escrita concorrente, com a constraint de exclusão e o 409 ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)). Separados, a disputa por horário não pesa no cadastro, e o cadastro pode mudar sem tocar na regra de reserva.
- **agendamento × disponibilidade:** é o CQRS ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)). A leitura é cerca de 50 vezes a escrita. Num serviço próprio, a consulta ganha réplicas sem carregar o banco que segura o lock, e o modelo de leitura (só os horários ocupados) é diferente do de escrita.
- **notificação separada:** depende de um provedor externo lento e com limite de taxa (o erro 429 da Aula 3). Pelo Kafka, o worker puxa as mensagens no ritmo que o provedor aguenta, e a falha ou a lentidão do provedor não afeta a reserva ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).
- **Um dono por container:** cada serviço tem uma pessoa responsável, com o próprio PR e o próprio ADR, como na ponte com o Team Topologies da Aula 1. Isso deixou cinco pessoas trabalharem ao mesmo tempo sem mexer nos mesmos arquivos.

### Sem chamada síncrona entre os serviços

Na Q11, o grupo tinha votado uma chamada REST do agendamento para o barbearia-service, para validar o serviço e o profissional no momento da reserva. O [roadmap](../roadmap.md) de 21/10 tirou essa chamada: o agendamento confia nos IDs que recebe, e os dados fixos da demo usam IDs conhecidos por todos. Os serviços só se falam pelo Kafka; o único caminho síncrono é BFF → serviço ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).

**Trade-off aceito:** o agendamento não confere se o profissional e o serviço existem, então aceita reserva para um ID inexistente. Há duas evoluções possíveis. Na primeira, o barbearia-service publica eventos de cadastro e o agendamento mantém uma cópia local, sem depender do outro serviço em tempo de reserva. Na segunda, a chamada REST votada na Q11 volta, com timeout e circuit breaker.

**Fora do diagrama:** front-ends (Q06), lembretes de véspera e de 1 h antes (Q17), expediente configurável e o evento `expediente.alterado`, pagamento, avaliações e fidelidade.

## Consequências

- Cinco pastas em `services/` ([ADR-0002](0002-monorepo-e-estrutura.md)), cada uma com o próprio Dockerfile e a própria imagem.
- A grade de horários é eventualmente consistente com a agenda. O agendamento decide sempre pela fonte da verdade (409), nunca pela grade.
- Mais containers para subir e observar: cada um manda logs, métricas e traces pelo OpenTelemetry, e o trace atravessa o Kafka ([ADR-0013](0013-entrega-continua-e-observabilidade.md)).
- Um BFF único atende todos os canais. Um BFF por canal (app do cliente × painel da barbearia) fica como evolução, se os canais existirem.

## Referências

- Aula 1 [01:02:18]–[01:08:52]: containers do PizzaExpress; um domínio grande com subdomínios vira container.
- Aula 1 [01:12:15]: cuidado com orquestração e regra de negócio no BFF.
- Aula 5 [00:04:33]: explicar por que os domínios foram divididos assim e por que microsserviços.
- RICHARDSON, Chris. **Pattern: decompose by subdomain**. Disponível em: <https://microservices.io/patterns/decomposition/decompose-by-subdomain.html>.
- SKELTON, Matthew; PAIS, Manuel. **Team topologies**: organizing business and technology teams for fast flow. Portland: IT Revolution Press, 2019.
- Votações: [Q06 (#6)](https://github.com/Allainn/barbearia-multiplataforma/issues/6), [Q07 (#7)](https://github.com/Allainn/barbearia-multiplataforma/issues/7), [Q09 (#9)](https://github.com/Allainn/barbearia-multiplataforma/issues/9), [Q11 (#11)](https://github.com/Allainn/barbearia-multiplataforma/issues/11), [Q17 (#17)](https://github.com/Allainn/barbearia-multiplataforma/issues/17).
