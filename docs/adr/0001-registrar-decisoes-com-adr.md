# ADR-0001: Registrar as decisões arquiteturais com ADRs

- **Status:** Aceito
- **Data:** 24/10/2026
- **Questão:** [Q23](../questoes-abertas.md#q23)
- **Afeta no diagrama:** nenhum elemento; define como o diagrama e as decisões evoluem

## Contexto

- A nota vem da **justificativa de cada decisão** ("escolhi Kafka por causa de…"). Precisamos chegar à apresentação com o porquê de cada escolha escrito, e não reconstruído de memória.
- Somos 7 pessoas com pouco tempo juntos (aulas às quartas, uma semana sem aula). As discussões vão ser assíncronas.
- Parte da implementação vai ser feita com agentes de IA (Claude Code). Um agente só respeita decisões que estão escritas no repositório.

## Opções consideradas

### A. ADRs em Markdown no repositório, discutidos em issues e aceitos por PR

- **Prós:** histórico versionado junto do código; o PR registra quem aprovou; o agente lê os ADRs; os slides saem quase prontos dos ADRs.
- **Contras:** exige disciplina para escrever; quem não usa Git no dia a dia tem uma curva inicial.

### B. Decisões só nas issues ou no GitHub Discussions

- **Prós:** zero atrito, tudo pelo navegador.
- **Contras:** a decisão final se perde no meio dos comentários; não há um documento por decisão para montar os slides.

### C. Documento único compartilhado (Google Docs, Notion, wiki)

- **Prós:** fácil de editar junto.
- **Contras:** fica fora do repositório (o agente não vê); sem histórico de quem aprovou o quê.

## Decisão

Opção **A**: ADRs em Markdown no repositório.

- Formato: [0000-template.md](0000-template.md) (baseado no modelo de Michael Nygard, em pt-BR).
- Numeração sequencial de 4 dígitos; arquivo `NNNN-titulo-com-hifen.md`. O [índice](README.md) liga cada ADR ao dono e ao nível do C4.
- Ciclo: *Proposto* → *Aceito* ou *Rejeitado*. Uma decisão aceita não é reescrita; outro ADR a substitui (*Substituído por ADR-NNNN*). Até a apresentação, o dono pode completar o ADR aceito da sua parte com o que foi implementado, no PR do código.

O jeito de aceitar mudou durante o trabalho:

1. **De 07 a 09/10:** cada questão teve uma issue com a label `questao` (#1 a #24), e o grupo votou nos comentários. Na Q23, o grupo votou como quórum 48 h sem objeção depois da última alteração.
2. **A partir de 21/10:** o [roadmap](../roadmap.md) fechou o escopo e passou cada ADR para quem implementa a parte. O ADR vira *Aceito* no mesmo PR do código, com a decisão que foi implementada de fato, e **o aceite é o merge desse PR**: 1 aprovação de outro integrante e a do code owner ([ADR-0002](0002-monorepo-e-estrutura.md)). As 48 h deixaram de valer, porque, a uma semana da apresentação, esperar dois dias por ADR não cabia no prazo.
3. **Em 24/10:** os ADRs gerais (0001 a 0005), que não pertencem a nenhuma parte, ficaram com o Allainn. As issues #1 a #24 foram fechadas, cada uma apontando para o ADR do tema.

## Consequências

- Cada decisão tem dono, data e aprovadores registrados no PR.
- Os slides de decisões saem dos ADRs aceitos, e cada um tem as alternativas consideradas, que é o que o professor avalia.
- Os agentes de IA de cada integrante leem os ADRs e o [tarefas.md](../tarefas.md) antes de mudar o código ([CLAUDE.md](../../CLAUDE.md)).
- Custo: o ADR precisa mudar no mesmo PR do código, ou a decisão escrita e o código se separam. A revisão de cada PR confere os dois juntos.

## Referências

- NYGARD, Michael. *Documenting architecture decisions*. 2011. Disponível em: <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>.
- Aula 1 [00:08:07]: a nota é a defesa do porquê de cada escolha.
- Votação da Q23: [issue #23](https://github.com/Allainn/barbearia-multiplataforma/issues/23).
