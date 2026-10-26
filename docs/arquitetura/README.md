# Arquitetura: C4 do BarberHub

> **Versão do roadmap de 21/10/2026, conferida com o código em 24/10/2026.** Só entra o que existe no código da demo; o contrato completo (portas, rotas, eventos, banco) está em [docs/tarefas.md](../tarefas.md#contrato).

- **Board no Miro (fonte dos diagramas dos slides):** <https://miro.com/app/board/uXjVEdd_Nsc=/>
- **Esta página:** espelho em Mermaid para revisar no GitHub e versionar junto do código. Quem mudar um container, tópico ou seta avisa o Allainn, que atualiza os dois.

**Legenda:** azul-escuro = pessoa · azul = dentro do sistema · cinza = sistema externo.

## Nível 1 · Contexto

```mermaid
flowchart TB
    cliente["<b>Cliente</b><br/>[Pessoa]<br/>Consulta horários livres, agenda e cancela"]
    gestor["<b>Gestor da barbearia</b><br/>[Pessoa]<br/>Cadastra barbearias, profissionais e serviços"]

    sistema["<b>BarberHub</b><br/>[Sistema de software]<br/>Plataforma multi-tenant de agendamento:<br/>muitas barbearias na mesma plataforma;<br/>o cliente consulta horários livres e agenda"]

    keycloak["<b>Keycloak 26</b><br/>[Sistema externo · IdP]<br/>Autentica usuários e emite JWT<br/>com as roles cliente e gestor"]
    mensagens["<b>Provedor de mensagens</b><br/>[Sistema externo · simulado]<br/>WhatsApp ou SMS; na demo,<br/>a mensagem vai para o log"]

    cliente -->|"Consulta horários, agenda e cancela [HTTPS]"| sistema
    gestor -->|"Cadastra barbearias, profissionais e serviços [HTTPS]"| sistema
    cliente -->|"Faz login e obtém o token [OAuth2/OIDC]"| keycloak
    gestor -->|"Faz login e obtém o token [OAuth2/OIDC]"| keycloak
    sistema -->|"Valida o JWT [JWKS]"| keycloak
    sistema -->|"Envia confirmação e cancelamento (simulado)"| mensagens

    classDef pessoa fill:#08427b,stroke:#052e56,color:#ffffff
    classDef interno fill:#1168bd,stroke:#0b4884,color:#ffffff
    classDef externo fill:#999999,stroke:#6b6b6b,color:#ffffff
    class cliente,gestor pessoa
    class sistema interno
    class keycloak,mensagens externo
```

## Nível 2 · Containers

```mermaid
flowchart TB
    pessoas["<b>Cliente · Gestor da barbearia</b><br/>[Pessoas]<br/>Na demo, chamadas com curl (scripts/demo.sh)"]
    keycloak["<b>Keycloak 26</b><br/>[Sistema externo · IdP]<br/>Realm barbearia; roles cliente e gestor"]
    mensagens["<b>Provedor de mensagens</b><br/>[Sistema externo · simulado]<br/>Na demo, a mensagem vai para o log"]

    subgraph barberhub["BarberHub · um PostgreSQL 16 (banco barbearia) com um schema e um usuário por serviço"]
        bff["<b>bff-gateway</b><br/>[Java 21 · Spring Boot 3 · :8010]<br/>Entrada única; valida o JWT (401/403)<br/>e repassa o X-User-ID"]
        barbearia["<b>barbearia-service</b><br/>[Python 3.12 · FastAPI · :8001]<br/>Barbearias, profissionais e serviços"]
        agendamento["<b>agendamento-service</b><br/>[Java 21 · Spring Boot 3 · :8012]<br/>Reserva e cancela; 409 se o horário<br/>já estiver ocupado"]
        disponibilidade["<b>disponibilidade-service</b><br/>[Python 3.12 · FastAPI · :8003]<br/>Horários livres (leitura do CQRS),<br/>grade das 09h às 18h"]
        notificacao["<b>notificacao-service</b><br/>[Python 3.12 · FastAPI · :8004]<br/>Consome os eventos e envia a mensagem;<br/>ignora evento repetido"]
        kafka[("<b>Kafka</b><br/>[Apache Kafka · KRaft]<br/>agendamento.criado · agendamento.cancelado<br/>3 partições, chave profissional_id")]
        pgB[("<b>PostgreSQL 16</b><br/>schema barbearia")]
        pgA[("<b>PostgreSQL 16</b><br/>schema agendamento<br/>(constraint de exclusão)")]
        pgD[("<b>PostgreSQL 16</b><br/>schema disponibilidade<br/>(read model)")]
        pgN[("<b>PostgreSQL 16</b><br/>schema notificacao")]
    end

    pessoas -->|"HTTPS/REST com JWT"| bff
    pessoas -->|"Obtém o token [OAuth2 · password grant na demo]"| keycloak
    bff -->|"Valida o JWT [JWKS]"| keycloak
    bff -->|"Cadastros e consultas [REST · X-User-ID]"| barbearia
    bff -->|"Reserva e cancela [REST · X-User-ID]"| agendamento
    bff -->|"Horários livres [REST · X-User-ID]"| disponibilidade
    agendamento -->|"Publica agendamento.criado e .cancelado [Kafka Producer]"| kafka
    kafka -->|"Consome os dois tópicos [Kafka Consumer]"| disponibilidade
    kafka -->|"Consome os dois tópicos [Kafka Consumer]"| notificacao
    notificacao -->|"Envia a mensagem (simulado: grava no log)"| mensagens
    barbearia -->|"SQL"| pgB
    agendamento -->|"SQL"| pgA
    disponibilidade -->|"SQL"| pgD
    notificacao -->|"SQL"| pgN

    classDef pessoa fill:#08427b,stroke:#052e56,color:#ffffff
    classDef interno fill:#1168bd,stroke:#0b4884,color:#ffffff
    classDef infra fill:#438dd5,stroke:#2e6295,color:#ffffff
    classDef externo fill:#999999,stroke:#6b6b6b,color:#ffffff
    class pessoas pessoa
    class bff,barbearia,agendamento,disponibilidade,notificacao interno
    class kafka,pgB,pgA,pgD,pgN infra
    class keycloak,mensagens externo
```

## Onde está cada decisão

No Miro, cada elemento tem uma etiqueta verde com link para o ADR. Aqui, a mesma relação:

| Elemento | ADR |
|---|---|
| BarberHub e o volume que justifica a arquitetura | [ADR-0003](../adr/0003-enquadramento-plataforma-multi-tenant.md) |
| Os 5 containers e os 2 tópicos | [ADR-0004](../adr/0004-decomposicao-em-servicos.md) |
| Java nos dois serviços com Spring Boot, Python nos três com FastAPI | [ADR-0005](../adr/0005-linguagens-por-servico.md) |
| REST do BFF para os serviços; Kafka entre o agendamento e os consumers | [ADR-0006](../adr/0006-comunicacao-sincrona-e-kafka.md) |
| Constraint de exclusão e 409 no agendamento | [ADR-0007](../adr/0007-concorrencia-na-reserva-de-horario.md) |
| disponibilidade-service como lado de leitura do CQRS | [ADR-0008](../adr/0008-cqrs-na-consulta-de-disponibilidade.md) |
| Keycloak como provedor de identidade | [ADR-0009](../adr/0009-seguranca-keycloak-e-validacao-jwt.md) |
| Roles cliente e gestor; JWT conferido só no BFF, que repassa o X-User-ID | [ADR-0014](../adr/0014-modelo-de-autorizacao-rbac.md), [ADR-0015](../adr/0015-onde-autenticar-e-autorizar.md) |
| Clean Architecture e DDD no agendamento | [ADR-0010](../adr/0010-arquitetura-interna-dos-servicos.md) |
| Um PostgreSQL com um schema e um usuário por serviço | [ADR-0011](../adr/0011-dados-por-servico.md) |

Fora dos diagramas: o CI/CD e a stack Grafana ([ADR-0013](../adr/0013-entrega-continua-e-observabilidade.md)) e a decisão de não usar Outbox ([ADR-0012](../adr/0012-garantia-de-publicacao-outbox.md)).

## Fluxo da demo

1. Sem token: **401**. Cliente cadastrando serviço: **403**.
2. Cliente consulta os horários livres (BFF → disponibilidade-service).
3. Duas reservas no mesmo horário ao mesmo tempo: **201** para uma, **409** para a outra (constraint de exclusão no agendamento-service).
4. O evento aparece no Kafka UI, a notificação aparece no log e o horário some da consulta.
5. Uma mudança no barbearia-service passa pelo pipeline, a nova versão sobe, `GET /barbearias` mostra a mudança e a latência aparece no Grafana.

## Nível 3

Fora do escopo do roadmap (corte por prazo).
