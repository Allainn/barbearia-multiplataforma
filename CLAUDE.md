# CLAUDE.md

Contexto e regras para o Claude Code (e para qualquer agente) que trabalhar neste repositório.

## Sobre o projeto

Trabalho final em grupo da disciplina **Arquitetura de Software Multiplataforma** (PUC Minas, prof. Messias Barbosa Bittencourt). Plataforma multi-tenant de agendamento para barbearias. Vale 100 pontos; apresentação de 20 minutos em **28/10/2026**.

O que o professor avalia: **integrações entre plataformas funcionando** e **justificativa das decisões arquiteturais**. Regras de negócio, front-end e qualidade fina de código não são avaliados. Regras completas em [docs/enunciado.md](docs/enunciado.md).

## Regras de trabalho para o agente

1. **Não tomar decisão arquitetural sozinho.** Se a tarefa depende de algo que não está num ADR *Aceito*, pare e registre: uma questão em [docs/questoes-abertas.md](docs/questoes-abertas.md) (e issue com a label `questao`) ou um ADR novo com status *Proposto*.
2. **Toda implementação cita a sua origem:** o ADR aceito ou a issue que a justifica (no PR e na mensagem de commit).
3. **ADR aceito não se edita.** Para mudar uma decisão, crie um ADR novo que o substitui e marque o antigo como *Substituído por ADR-NNNN*.
4. **Tudo o que estiver no diagrama C4 precisa existir no código**, e vice-versa. Ao criar ou remover um container, tópico ou seta, atualize [docs/arquitetura](docs/arquitetura/README.md) e avise que o board do Miro precisa ser atualizado.
5. **Nada mirabolante:** prefira a solução mais simples que demonstre a integração pedida.
6. **Nunca commitar na `main`.** Ela é protegida: trabalhe numa branch e abra PR. O merge exige 1 aprovação e a aprovação do @Allainn (code owner). Detalhes em [CONTRIBUTING.md](CONTRIBUTING.md#branches-e-commits).

## Estrutura

```
.
├── docs/
│   ├── enunciado.md            # regras do professor, checklist, roteiro da apresentação
│   ├── questoes-abertas.md     # questões por nível do C4 (espelhadas nas issues)
│   ├── adr/                    # ADRs numerados (0000-template.md + NNNN-titulo.md)
│   └── arquitetura/            # link do Miro e espelho Mermaid do C4
├── services/                   # um diretório por serviço (vazio até os ADRs serem aceitos)
├── infra/                      # docker-compose, k8s, observabilidade (idem)
└── .github/                    # templates de issue e PR; workflows de CI depois do ADR-0013
```

## Convenções

- **Idioma:** documentação em português (pt-BR); termos técnicos consagrados em inglês (BFF, CQRS, consumer group…). O idioma do código (nomes de classes, tópicos, endpoints) está em aberto: [Q23](docs/questoes-abertas.md#q23).
- **Nomes de arquivo:** minúsculas, com hífen, sem acentos.
- **ADRs:** formato de [docs/adr/0000-template.md](docs/adr/0000-template.md); status *Proposto* → *Aceito* / *Rejeitado* / *Substituído*. Detalhes do fluxo em [CONTRIBUTING.md](CONTRIBUTING.md).
- **Commits:** Conventional Commits em português (`feat(agendamento): ...`, `docs(adr): ...`).

## Referência de implementação

O PizzaExpress do professor (Python/FastAPI + Java/Spring Boot, Keycloak, Kafka, Postgres, stack Grafana) é a base de código a reaproveitar. Ele **não** é o tema. Onde está cada exemplo: [docs/enunciado.md → Referência de implementação](docs/enunciado.md#referência-de-implementação-pizzaexpress).
