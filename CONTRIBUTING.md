# Como contribuir

Fluxo proposto no [ADR-0001](docs/adr/0001-registrar-decisoes-com-adr.md) e no [ADR-0002](docs/adr/0002-monorepo-e-estrutura.md). Enquanto esses ADRs estiverem como *Proposto*, este fluxo também está em discussão.

## Decisões: questão → ADR → aceite

1. **Questão.** Toda dúvida que muda a arquitetura vira uma issue com a label `questao` (template "Questão para decisão") e entra em [docs/questoes-abertas.md](docs/questoes-abertas.md). A issue diz qual parte do diagrama C4 ela afeta.
2. **Discussão.** Cada integrante comenta na issue: concorda, discorda ou traz outra opção. Vale reagir com 👍/👎 no comentário que resume a proposta.
3. **ADR.** Quem conduz a questão abre um PR com o ADR (copiado de [0000-template.md](docs/adr/0000-template.md)) ou atualiza o ADR *Proposto* que já existe: alternativas, decisão e consequências.
4. **Aceite.** O ADR vai para *Aceito* quando o PR tiver a aprovação do quórum combinado na [Q23](docs/questoes-abertas.md#q23) (sugestão: 4 dos 7 integrantes, ou 48 h sem objeção depois da última mudança). O PR fecha a issue com `Closes #N`.
5. **Implementação.** Só começa a partir de ADR *Aceito*. Cada tarefa vira uma issue (template "Tarefa") que cita o ADR.

Para mudar uma decisão já aceita, abra um ADR novo que **substitui** o anterior; não reescreva o histórico.

## Branches e commits

- `main` protegida (desde 07/10/2026): **ninguém faz push direto**, tudo entra por PR. Para o merge, o PR precisa de:
  - **1 aprovação** de outro integrante (o autor não conta);
  - **aprovação do @Allainn** como code owner ([.github/CODEOWNERS](.github/CODEOWNERS)). Nos PRs do próprio Allainn, essa segunda regra é dispensada no merge, mas a aprovação de um colega continua obrigatória.
  - Um novo push depois da aprovação invalida a aprovação; é preciso aprovar de novo.
- Para revisar e aprovar, o integrante precisa ser colaborador do repositório com permissão de escrita.
- Nome da branch: `adr/0007-lock-reserva`, `feat/agendamento-reserva`, `fix/...`, `docs/...`, `infra/...`.
- Commits no padrão Conventional Commits, em português: `feat(agendamento): reserva com constraint de exclusão`, `docs(adr): aceita ADR-0006`.

## Labels

| Label | Uso |
|---|---|
| `questao` | Decisão em aberto (vira ADR) |
| `adr` | PR ou issue que cria ou altera um ADR |
| `c4-contexto` · `c4-container` · `c4-componente` | Parte do diagrama que a questão ou tarefa afeta |
| `entrega` | CI/CD, observabilidade, demo, slides |
| `organizacao` | Papéis, prazos, convenções do grupo |
| `prioridade-alta` | Bloqueia outras decisões ou o C4 |
| `tarefa` | Trabalho de implementação já decidido |

## Diagrama

O esboço do C4 fica no board do Miro (link em [docs/arquitetura](docs/arquitetura/README.md)). Quando uma questão for decidida, quem fechou a questão atualiza o board **e** o espelho Mermaid no mesmo PR do ADR.

## Uso de IA (Claude Code)

Permitido, desde que o grupo valide que o código funciona. O agente segue o [CLAUDE.md](CLAUDE.md): não decide arquitetura sozinho e cita o ADR ou a issue de cada mudança.
