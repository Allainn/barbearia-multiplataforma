# Como contribuir

Desde 21/10/2026 o trabalho segue o [roadmap](docs/roadmap.md) e as [tarefas](docs/tarefas.md). A fase de decisões por issues (07 a 09/10) terminou: as 24 questões foram votadas, e o roadmap fechou o escopo e o contrato.

## Fluxo de uma parte

1. **Pegue a sua parte** em [docs/tarefas.md](docs/tarefas.md). Se for usar IA, entregue o arquivo a ela; a seção "Para a IA que está lendo este arquivo" diz o que ela pode e não pode fazer.
2. **Crie a branch** `feat/<sua-parte>` a partir da `main`.
3. **Teste sozinho** contra a infra do PizzaExpress, sem esperar ninguém ([tarefas → Como testar sozinho](docs/tarefas.md#como-testar-sozinho)).
4. **Abra o PR** quando todos os itens de "Pronto quando" da sua seção passarem.
5. **No mesmo PR, aceite o ADR da sua parte:** status *Aceito*, data do PR, seção "Decisão" reescrita com o que foi implementado, seção "Perguntas para o grupo" apagada e opções consideradas mantidas. O índice `docs/adr/README.md` é atualizado pelo Allainn.
6. **Revisão:** o Allainn revisa e aprova no mesmo dia em que o PR é aberto.

O contrato (containers, portas, variáveis, banco, rotas, eventos, Keycloak e dados fixos) **só muda com aviso no grupo**. Não abra issues.

## Branches e commits

- `main` protegida (desde 07/10/2026): **ninguém faz push direto**, tudo entra por PR. Para o merge, o PR precisa de:
  - **1 aprovação** de outro integrante (o autor não conta);
  - **aprovação do @Allainn** como code owner ([.github/CODEOWNERS](.github/CODEOWNERS)). Nos PRs do próprio Allainn, essa segunda regra é dispensada no merge, mas a aprovação de um colega continua obrigatória.
  - Um novo push depois da aprovação invalida a aprovação; é preciso aprovar de novo.
- Para revisar e aprovar, o integrante precisa ser colaborador do repositório com permissão de escrita (convites enviados em 21/10).
- Nome da branch: `feat/<sua-parte>` (ex.: `feat/agendamento-service`). Documentação: `docs/...`. Ensaio do pipeline: `demo/**`.
- Commits no padrão Conventional Commits, em português, citando o ADR: `feat(agendamento): reserva com constraint de exclusão (ADR-0007)`, `docs(adr): aceita ADR-0006`.

## Diagrama

O C4 (níveis 1 e 2) fica no board do Miro e no espelho Mermaid de [docs/arquitetura](docs/arquitetura/README.md); quem atualiza é o Allainn. Se a sua parte criar ou remover um container, tópico ou seta, avise.

## Uso de IA (Claude Code)

Permitido, desde que o grupo valide que o código funciona. O agente segue o [CLAUDE.md](CLAUDE.md), que aponta para o roadmap e as tarefas.

## Histórico: questões e labels

As questões Q01 a Q24 (issues #1 a #24) foram votadas de 07 a 09/10 e ficam como registro do porquê das decisões. As labels (`questao`, `c4-contexto`, `c4-container`, `c4-componente`, `entrega`, `organizacao`, `prioridade-alta`, `tarefa`) foram usadas nessa fase.
