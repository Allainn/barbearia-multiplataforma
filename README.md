# Barbearia Multiplataforma

Trabalho final da disciplina **Arquitetura de Software Multiplataforma** (pós em Arquitetura de Software Distribuído, PUC Minas), prof. Messias Barbosa Bittencourt.

> **Situação:** fase de decisões. Os ADRs estão como *Proposto* e as questões estão abertas como issues. A implementação começa quando os ADRs forem aceitos pelo grupo.

## O sistema (rascunho)

Plataforma **multi-tenant** de agendamento para barbearias: muitas barbearias usam a mesma plataforma para gerir a agenda dos profissionais, e os clientes buscam horários e agendam em qualquer uma delas. O nome do produto ainda está em aberto ([Q02](docs/questoes-abertas.md#q02)).

O enquadramento com escala e a volumetria assumida estão no [ADR-0003](docs/adr/0003-enquadramento-plataforma-multi-tenant.md). O esboço dos containers está no [ADR-0004](docs/adr/0004-decomposicao-em-servicos.md) e em [docs/arquitetura](docs/arquitetura/README.md).

## Onde está cada coisa

| O quê | Onde |
|---|---|
| Regras do trabalho, checklist e data de entrega | [docs/enunciado.md](docs/enunciado.md) |
| Decisões arquiteturais (ADRs) | [docs/adr/](docs/adr/README.md) |
| Questões para o grupo decidir, organizadas por nível do C4 | [docs/questoes-abertas.md](docs/questoes-abertas.md) e issues com a label `questao` |
| Esboço do C4 (níveis 1 e 2) | Board no Miro (link em [docs/arquitetura](docs/arquitetura/README.md)) + espelho em Mermaid |
| Como contribuir (ADR, issues, PR, branches) | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Contexto para o Claude Code | [CLAUDE.md](CLAUDE.md) |
| Código dos serviços | `services/` (vazio até os ADRs serem aceitos) |
| Infraestrutura (Docker Compose, Kubernetes, observabilidade) | `infra/` (vazio até os ADRs serem aceitos) |

## Grupo

| Integrante | Papel |
|---|---|
| Allainn Christiam Jacinto Tavares | _a definir ([Q22](docs/questoes-abertas.md#q22))_ |
| Daniel da Silveira Moreira | _a definir_ |
| Evandro Vieira de Carvalho Júnior | _a definir_ |
| Gabriel Santiago Silva | _a definir_ |
| Guilherme Nunes Faria | _a definir_ |
| João Almeida Barbosa Júnior | _a definir_ |
| Pedro Assis Corrêa | _a definir_ |

## Cronograma

| Até | Entrega | Milestone |
|---|---|---|
| 14/10 (semana sem aula) | Tema enquadrado, C4 níveis 1 e 2, ADRs principais aceitos | `S1 - Decisões e C4` |
| 21/10 (Aula 5) | Integrações funcionando: segurança (401/403), Kafka, CQRS e lock | `S2 - Integrações` |
| 26/10 | CI/CD, observabilidade, slides e ensaio ou gravação | `S3 - Entrega e apresentação` |
| 28/10 (Aula 6) | Apresentação (20 min) e postagem no Canvas | `S3 - Entrega e apresentação` |
