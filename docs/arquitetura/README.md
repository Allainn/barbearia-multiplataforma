# Arquitetura: esboço do C4

> **Esboço para discussão.** Reflete os ADRs *Propostos* de 07/10/2026; nada está aceito. Onde houver **(Qnn)**, o elemento depende daquela [questão em aberto](../questoes-abertas.md).

- **Board no Miro (fonte do esboço, para discutir e mexer junto):** <https://miro.com/app/board/uXjVEdd_Nsc=/>
- **Esta página:** espelho em texto (Mermaid) para revisar no GitHub e versionar junto dos ADRs. Quem fechar uma questão atualiza os dois.
- **Versão final para a apresentação:** a definir na [Q24](../questoes-abertas.md#q24) (sugestão: draw.io com a notação C4, como o professor usa).

**Legenda:** azul = dentro do sistema · cinza = sistema externo · azul-escuro = pessoa · tracejado = em aberto ou fora do escopo.

## Nível 1 · Contexto

```mermaid
flowchart TB
    cliente["<b>Cliente</b><br/>[Pessoa]<br/>Busca horários, agenda e cancela"]
    profissional["<b>Profissional</b><br/>[Pessoa]<br/>Consulta a própria agenda"]
    gestor["<b>Gestor da barbearia</b><br/>[Pessoa]<br/>Cadastra serviços, profissionais e expediente"]
    admin["<b>Administrador da plataforma</b><br/>[Pessoa]<br/>Aprova barbearias"]

    sistema["<b>Plataforma de agendamento</b> (nome: Q02)<br/>[Sistema de software]<br/>Marketplace multi-tenant: muitas barbearias,<br/>clientes agendam em qualquer uma (Q01)"]

    keycloak["<b>Keycloak</b><br/>[Sistema externo · IdP]<br/>Autentica usuários e emite JWT com roles"]
    mensagens["<b>Provedor de mensagens</b><br/>[Sistema externo · simulado]<br/>WhatsApp, SMS ou e-mail (Q05)"]
    pagamento["<b>Gateway de pagamento</b><br/>[Sistema externo]<br/>Sinal contra no-show (Q05: fora?)"]

    cliente -->|"Busca horários, agenda e cancela [HTTPS]"| sistema
    profissional -->|"Consulta a agenda [HTTPS]"| sistema
    gestor -->|"Gerencia a barbearia [HTTPS]"| sistema
    admin -->|"Administra a plataforma [HTTPS]"| sistema
    sistema -->|"Autentica (OIDC) e valida tokens (JWKS)"| keycloak
    sistema -->|"Envia confirmações e cancelamentos [HTTPS]"| mensagens
    sistema -.->|"Cobra sinal (fora do escopo?)"| pagamento

    classDef pessoa fill:#08427b,stroke:#052e56,color:#ffffff
    classDef interno fill:#1168bd,stroke:#0b4884,color:#ffffff
    classDef externo fill:#999999,stroke:#6b6b6b,color:#ffffff
    classDef aberto fill:#ffffff,stroke:#999999,color:#666666,stroke-dasharray: 5 5
    class cliente,profissional,gestor,admin pessoa
    class sistema interno
    class keycloak,mensagens externo
    class pagamento aberto
```

## Nível 2 · Containers

```mermaid
flowchart TB
    pessoas["<b>Cliente · Profissional · Gestor · Admin</b><br/>[Pessoas]<br/>via curl/Postman na demo; apps fora do escopo (Q06)"]
    keycloak["<b>Keycloak 26</b><br/>[Sistema externo · IdP]"]
    mensagens["<b>Provedor de mensagens</b><br/>[Sistema externo · simulado]"]

    subgraph plataforma["Plataforma de agendamento (nome: Q02)"]
        bff["<b>bff-gateway</b><br/>[Java 21 · Spring Boot]<br/>Entrada única; valida JWT (401/403) (Q09, Q13)"]
        barbearia["<b>barbearia-service</b><br/>[Python 3.12 · FastAPI]<br/>Barbearias, profissionais, serviços, expediente"]
        agendamento["<b>agendamento-service</b><br/>[Java 21 · Spring Boot]<br/>Reserva e cancela; lock contra double booking (Q14)"]
        disponibilidade["<b>disponibilidade-service</b><br/>[Python 3.12 · FastAPI]<br/>Horários livres: read model do CQRS (Q15)"]
        notificacao["<b>notificacao-service</b><br/>[Python 3.12 · FastAPI · worker]<br/>Confirmações e cancelamentos (Q17)"]
        kafka[("<b>Kafka</b><br/>[Apache Kafka · KRaft]<br/>agendamento.criado · agendamento.cancelado ·<br/>expediente.alterado (Q10)")]
        postgres[("<b>PostgreSQL 16</b><br/>schemas: barbearia · agendamento ·<br/>disponibilidade · notificacao (Q12)")]
    end

    pessoas -->|"Chamadas com JWT [HTTPS/REST]"| bff
    pessoas -.->|"Login (OIDC) para obter o token"| keycloak
    bff -->|"Valida assinatura do JWT [JWKS]"| keycloak
    bff -->|"Cadastros [REST]"| barbearia
    bff -->|"Reservar, cancelar [REST]"| agendamento
    bff -->|"Consultar horários livres [REST]"| disponibilidade
    agendamento -->|"Valida serviço e expediente [REST] (Q11)"| barbearia
    agendamento -->|"Revalida JWT e tenant [JWKS] (Q13)"| keycloak
    agendamento -->|"Publica agendamento.* via Outbox (Q16)"| kafka
    barbearia -->|"Publica expediente.alterado"| kafka
    kafka -->|"Consome agendamento.* e expediente.alterado"| disponibilidade
    kafka -->|"Consome agendamento.*"| notificacao
    notificacao -->|"Envia mensagem [HTTPS]"| mensagens
    barbearia -->|"SQL · schema barbearia"| postgres
    agendamento -->|"SQL · schema agendamento (constraint de exclusão)"| postgres
    disponibilidade -->|"SQL · schema disponibilidade"| postgres
    notificacao -->|"SQL · schema notificacao"| postgres

    classDef pessoa fill:#08427b,stroke:#052e56,color:#ffffff
    classDef interno fill:#1168bd,stroke:#0b4884,color:#ffffff
    classDef infra fill:#438dd5,stroke:#2e6295,color:#ffffff
    classDef externo fill:#999999,stroke:#6b6b6b,color:#ffffff
    class pessoas pessoa
    class bff,barbearia,agendamento,disponibilidade,notificacao interno
    class kafka,postgres infra
    class keycloak,mensagens externo
```

## Fluxo principal da demo (resumo)

1. Cliente obtém o token no Keycloak e chama o BFF (sem token: **401**; role errada: **403**).
2. Consulta horários livres → BFF → disponibilidade-service (read model).
3. Reserva → BFF → agendamento-service → valida no barbearia-service → grava com a constraint de exclusão (disputa: **409**) → Outbox → Kafka.
4. Kafka → disponibilidade-service atualiza o read model (o horário some da consulta) e notificacao-service envia a confirmação.
5. Trace da reserva inteira no Grafana (Tempo) e a latência no dashboard.

## Nível 3

A definir depois do [ADR-0010](../adr/0010-arquitetura-interna-dos-servicos.md). Proposta: componentes do agendamento-service (controller → use cases → aggregate `Agendamento` → repositório PostgreSQL e Outbox → publicador Kafka).
