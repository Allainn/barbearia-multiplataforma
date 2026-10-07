# ADR-0001: Registrar as decisões arquiteturais com ADRs

- **Status:** Proposto
- **Data:** 07/10/2026
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

**Proposta:** opção A.

- Formato: [0000-template.md](0000-template.md) (baseado no modelo de Michael Nygard, em pt-BR).
- Numeração sequencial de 4 dígitos; arquivo `NNNN-titulo-com-hifen.md`.
- Ciclo: *Proposto* → *Aceito* ou *Rejeitado*. Uma decisão aceita não é reescrita; outro ADR a substitui (*Substituído por ADR-NNNN*).
- A discussão acontece na issue `questao` ligada ao ADR; o aceite é o merge do PR que muda o status.
- Quórum para aceitar: **a definir** (sugestão: 4 dos 7 integrantes aprovam o PR, ou 48 h sem objeção depois da última alteração).

## Consequências

- Cada decisão tem dono, data e aprovadores registrados.
- A seção "Decisões" dos slides é montada a partir dos ADRs aceitos.
- Custo: alguém precisa conduzir cada questão até virar ADR. Sugestão: o dono da questão é quem a levantou ou quem vai implementar.

## Perguntas para o grupo

- Qual o quórum para aceitar um ADR (maioria, prazo sem objeção, ou os dois)?
- Quem tem pouca familiaridade com PR? Vale fazer uma sessão rápida de 15 min para todos.

## Referências

- NYGARD, Michael. *Documenting architecture decisions*. 2011. Disponível em: <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>.
- Aula 1 [00:08:07]: a nota é a defesa do porquê de cada escolha.
