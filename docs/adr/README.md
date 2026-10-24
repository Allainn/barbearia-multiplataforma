# ADRs (Architecture Decision Records)

Cada decisão arquitetural fica num arquivo numerado. Formato em [0000-template.md](0000-template.md); fluxo de aprovação em [CONTRIBUTING.md](../../CONTRIBUTING.md).

**Status:** *Proposto* (em discussão) → *Aceito* ou *Rejeitado*. Um ADR aceito não é reescrito; outro ADR o substitui.

Os ADRs foram escritos como rascunho em 07/10/2026 e votados nas issues #1 a #24, de 07 a 09/10. O [roadmap](../roadmap.md) de 21/10 cortou o escopo para caber no prazo. Desde então, quem implementa uma parte passa o ADR dela para *Aceito* no PR do código, com o que foi feito de fato. O dono de cada ADR vem do [tarefas.md](../tarefas.md); o C4 nível 3 ficou fora do escopo.

**Situação em 24/10/2026:**

| ADR | Decisão | Status | Dono | Nível do C4 |
|---|---|---|---|---|
| [0001](0001-registrar-decisoes-com-adr.md) | Registrar as decisões com ADRs | Proposto | sem dono | — |
| [0002](0002-monorepo-e-estrutura.md) | Monorepo e estrutura de pastas | Proposto | sem dono | — |
| [0003](0003-enquadramento-plataforma-multi-tenant.md) | Plataforma multi-tenant de agendamento (escala e volumetria) | Proposto | sem dono | 1 |
| [0004](0004-decomposicao-em-servicos.md) | Decomposição em 5 containers | Proposto | sem dono | 2 |
| [0005](0005-linguagens-por-servico.md) | Java no BFF e no agendamento; Python nos outros três | Proposto | sem dono | 2 |
| [0006](0006-comunicacao-sincrona-e-kafka.md) | REST do BFF para os serviços; Kafka com 2 tópicos do agendamento para os consumers | Aceito (22/10) | Daniel | 2 |
| [0007](0007-concorrencia-na-reserva-de-horario.md) | Lock na reserva: constraint de exclusão no PostgreSQL e 409 | Aceito (21/10) | Pedro | 2 |
| [0008](0008-cqrs-na-consulta-de-disponibilidade.md) | CQRS: read model da disponibilidade em serviço próprio, atualizado pelo Kafka | Aceito (23/10) | Gabriel | 2 |
| [0009](0009-seguranca-keycloak-e-validacao-jwt.md) | Keycloak 26 e onde validar o JWT (pelo roadmap, só no BFF) | Proposto; vira *Aceito* no PR do BFF | Evandro | 1, 2 |
| [0010](0010-arquitetura-interna-dos-servicos.md) | Clean Architecture em todos os serviços; DDD tático no agendamento | Aceito (21/10) | Pedro | — |
| [0011](0011-dados-por-servico.md) | Um PostgreSQL com um schema e um usuário por serviço; multi-tenancy em pool | Aceito (22/10) | João | 2 |
| [0012](0012-garantia-de-publicacao-outbox.md) | Outbox Pattern, rejeitado por prazo: fica o dual write, com o risco documentado | Rejeitado (21/10) | Pedro | — |
| [0013](0013-entrega-continua-e-observabilidade.md) | GitHub Actions, GHCR e deploy pelo Compose; stack Grafana (Loki, Tempo, Prometheus) | Aceito (22/10) | João | — |

## Como as decisões se encaixam

- **Por que essa arquitetura:** o volume do [0003](0003-enquadramento-plataforma-multi-tenant.md) justifica o resto.
- **Escrita × leitura:** pouca escrita, com disputa pelo mesmo horário → lock no banco ([0007](0007-concorrencia-na-reserva-de-horario.md)). Muita leitura → CQRS ([0008](0008-cqrs-na-consulta-de-disponibilidade.md)). Os dois se ligam pelos eventos no Kafka ([0006](0006-comunicacao-sincrona-e-kafka.md)), publicados depois do commit e sem Outbox ([0012](0012-garantia-de-publicacao-outbox.md)): se o Kafka cair nesse intervalo, a reserva continua valendo, mas a grade de horários fica desatualizada.
- **Multi-tenant:** `barbearia_id` nas tabelas, no modelo pool ([0011](0011-dados-por-servico.md)). O 403 entre barbearias ficou fora por prazo ([0009](0009-seguranca-keycloak-e-validacao-jwt.md)).
- **Entrega:** pipeline, publicação da imagem e os três pilares da observabilidade no Grafana ([0013](0013-entrega-continua-e-observabilidade.md)).
