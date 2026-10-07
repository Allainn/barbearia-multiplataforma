# ADRs (Architecture Decision Records)

Cada decisão arquitetural fica num arquivo numerado. Formato em [0000-template.md](0000-template.md); fluxo de aprovação em [CONTRIBUTING.md](../../CONTRIBUTING.md).

**Status:** *Proposto* (em discussão) → *Aceito* ou *Rejeitado*. Um ADR aceito não é reescrito; outro ADR o substitui.

Todos os ADRs abaixo foram escritos como **rascunho para discussão** em 07/10/2026. Cada um traz as alternativas, uma proposta e as perguntas que o grupo precisa responder.

| ADR | Decisão | Status | Questões | Nível do C4 |
|---|---|---|---|---|
| [0001](0001-registrar-decisoes-com-adr.md) | Registrar as decisões com ADRs | Proposto | Q23 | — |
| [0002](0002-monorepo-e-estrutura.md) | Monorepo e estrutura de pastas | Proposto | Q23 | — |
| [0003](0003-enquadramento-plataforma-multi-tenant.md) | Plataforma multi-tenant de agendamento (escala e volumetria) | Proposto | Q01, Q03 | 1 |
| [0004](0004-decomposicao-em-servicos.md) | Decomposição em serviços (5 containers) | Proposto | Q07, Q09 | 2 |
| [0005](0005-linguagens-por-servico.md) | Linguagens: Java + Python | Proposto | Q08 | 2 |
| [0006](0006-comunicacao-sincrona-e-kafka.md) | Síncrono × assíncrono; Kafka e tópicos | Proposto | Q10, Q11 | 2 |
| [0007](0007-concorrencia-na-reserva-de-horario.md) | Lock na reserva: constraint de exclusão + 409 | Proposto | Q14 | 2, 3 |
| [0008](0008-cqrs-na-consulta-de-disponibilidade.md) | CQRS completo na consulta de disponibilidade | Proposto | Q15 | 2 |
| [0009](0009-seguranca-keycloak-e-validacao-jwt.md) | Keycloak + validação híbrida do JWT + tenant | Proposto | Q13 | 1, 2 |
| [0010](0010-arquitetura-interna-dos-servicos.md) | Clean Architecture + DDD no agendamento | Proposto | Q18 | 3 |
| [0011](0011-dados-por-servico.md) | PostgreSQL com schema por serviço; multi-tenancy em pool | Proposto | Q12 | 2 |
| [0012](0012-garantia-de-publicacao-outbox.md) | Outbox com polling | Proposto | Q16 | 2, 3 |
| [0013](0013-entrega-continua-e-observabilidade.md) | CI/CD com GitOps e stack Grafana (revisar após a Aula 4) | Proposto | Q19, Q20 | — |

## Como as decisões se encaixam

- **Por que essa arquitetura:** o volume do [0003](0003-enquadramento-plataforma-multi-tenant.md) justifica o resto.
- **Escrita × leitura:** pouca escrita com muita disputa → lock no banco ([0007](0007-concorrencia-na-reserva-de-horario.md)); muita leitura → CQRS ([0008](0008-cqrs-na-consulta-de-disponibilidade.md)). Os dois se ligam por eventos no Kafka ([0006](0006-comunicacao-sincrona-e-kafka.md)), publicados com garantia ([0012](0012-garantia-de-publicacao-outbox.md)).
- **Multi-tenant:** a mesma decisão aparece na segurança (403 entre barbearias, [0009](0009-seguranca-keycloak-e-validacao-jwt.md)) e nos dados (coluna `barbearia_id`, [0011](0011-dados-por-servico.md)).
