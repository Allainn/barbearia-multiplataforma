# Barbearia Multiplataforma

Trabalho final da disciplina **Arquitetura de Software Multiplataforma** (pós em Arquitetura de Software Distribuído, PUC Minas), prof. Messias Barbosa Bittencourt.

> **Situação (21/10/2026):** implementação. O escopo, o contrato e a parte de cada pessoa estão no [roadmap](docs/roadmap.md) e nas [tarefas](docs/tarefas.md). Cada parte passa o seu ADR para *Aceito* no PR do código. Apresentação em **28/10/2026**.

## O sistema

Plataforma **multi-tenant** de agendamento para barbearias (nome votado na Q02: **BarberHub**): muitas barbearias usam a mesma plataforma, e os clientes consultam horários livres e agendam. O enquadramento com escala e a volumetria assumida estão no [ADR-0003](docs/adr/0003-enquadramento-plataforma-multi-tenant.md).

Na demo: o cliente obtém o token no Keycloak e chama o BFF, que valida o token (401/403) e encaminha para os serviços. O agendamento grava a reserva, e uma constraint do PostgreSQL impede dois agendamentos sobrepostos para o mesmo profissional (409 para o segundo). O evento vai para o Kafka e é consumido pela notificação e pela disponibilidade (lado de leitura do CQRS).

## Onde está cada coisa

| O quê | Onde |
|---|---|
| Plano até a apresentação: escopo, contrato e datas | [docs/roadmap.md](docs/roadmap.md) |
| Passo a passo de cada pessoa (para entregar à IA de cada um) | [docs/tarefas.md](docs/tarefas.md) |
| Regras do trabalho e checklist do professor | [docs/enunciado.md](docs/enunciado.md) |
| Decisões arquiteturais (ADRs) | [docs/adr/](docs/adr/README.md) |
| C4 (níveis 1 e 2) | [Board no Miro](https://miro.com/app/board/uXjVEdd_Nsc=/) + espelho em Mermaid em [docs/arquitetura](docs/arquitetura/README.md) |
| Questões votadas de 07 a 09/10 (histórico) | [docs/questoes-abertas.md](docs/questoes-abertas.md) e issues #1 a #24 |
| Como contribuir (branches, PR, aprovação) | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Contexto para o Claude Code | [CLAUDE.md](CLAUDE.md) |
| Código dos serviços | `services/<container>/` |
| Infraestrutura (Docker Compose, Grafana) | `infra/` |

## Grupo

| Integrante | Parte |
|---|---|
| Allainn Christiam Jacinto Tavares | C4, ADRs 0001 a 0005, slides e revisão dos PRs |
| João Almeida Barbosa Júnior | Infra, CI/CD e Grafana |
| Evandro Vieira de Carvalho Júnior | Keycloak e bff-gateway |
| Pedro Assis Corrêa | agendamento-service |
| Daniel da Silveira Moreira | notificacao-service |
| Gabriel Santiago Silva | disponibilidade-service |
| Guilherme Nunes Faria | barbearia-service e roteiro da demo |

## Cronograma

| Até | O quê |
|---|---|
| Sex 23/10 | Cada parte rodando sozinha contra a infra do PizzaExpress |
| Sáb 24/10 | PRs abertos; o `infra/` sobe tudo junto |
| Dom 25/10 | Integração: `scripts/demo.sh` do começo ao fim |
| Seg 26/10 | Pipeline e Grafana funcionando, slides e ADRs prontos, código congelado |
| Ter 27/10 | Ensaio de 20 min e gravação da demo como reserva |
| Qua 28/10 | Apresentação e postagem no Canvas |
