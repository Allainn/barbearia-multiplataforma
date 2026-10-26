# ADR-0002: Monorepo e estrutura de pastas

- **Status:** Aceito
- **Data:** 24/10/2026
- **Questão:** [Q23](../questoes-abertas.md#q23)
- **Afeta no diagrama:** nenhum elemento; cada container do C4 nível 2 vira uma pasta em `services/`

## Contexto

- São 5 serviços em 2 linguagens, além da infraestrutura (Keycloak, Kafka, PostgreSQL, stack de observabilidade) e da documentação.
- A demo precisa subir tudo de uma vez com o Docker Compose, e o pipeline precisa publicar a imagem de um serviço sem reconstruir os outros.
- O professor vai clonar o repositório, seguir o README numa máquina limpa e usar uma IA para mapear os pontos de entrada (Aula 5 [00:16:02], [00:18:14]). Tudo precisa estar num lugar só.

## Opções consideradas

### A. Monorepo (um repositório com serviços, infraestrutura e documentação)

- **Prós:** um único `docker-compose` para subir o ambiente; ADRs junto do código; mudanças que cruzam serviços (ex.: contrato de evento) num único PR; o agente de IA enxerga tudo.
- **Contras:** o CI precisa de filtro por pasta para não reconstruir tudo; permissões não são separadas por serviço.

### B. Um repositório por serviço (polyrepo)

- **Prós:** independência real de deploy e de permissões; espelha times separados.
- **Contras:** para o prazo e 7 pessoas é sobrecarga: 5 ou mais repositórios, contratos duplicados, ambiente montado com vários clones.

## Decisão

Opção **A**: um repositório público no GitHub, [Allainn/barbearia-multiplataforma](https://github.com/Allainn/barbearia-multiplataforma), com esta estrutura:

```
.
├── docs/            # roadmap, tarefas (com o contrato), enunciado, ADRs e C4 em Mermaid
├── services/        # um container do C4 nível 2 por pasta
│   ├── bff-gateway/             # Java
│   ├── barbearia-service/       # Python
│   ├── agendamento-service/     # Java
│   ├── disponibilidade-service/ # Python
│   └── notificacao-service/     # Python
├── infra/           # docker-compose.yml e config/ (PostgreSQL, Keycloak, OTel Collector, Prometheus, Loki, Tempo, Grafana)
├── scripts/         # up, down e deploy; seed do Keycloak; roteiros da demo
├── contracts/       # só um README que aponta para o contrato no tarefas.md
└── .github/         # workflow do pipeline, CODEOWNERS e templates de PR e de issue
```

- **Contrato entre os serviços:** rotas, eventos, banco, Keycloak e dados fixos ficaram num documento só, o [tarefas.md](../tarefas.md#contrato), que cada integrante entregou à própria IA. A pasta `contracts/`, pensada para JSON Schema, AsyncAPI e OpenAPI, ficou só com um README que aponta para lá. Os contratos em formato de máquina ficaram como evolução ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)); o Swagger que o FastAPI gera documenta as rotas dos serviços Python.
- **Branches:** `feat/<parte>` para a primeira entrega de cada parte, `fix/<parte>` para correções, `docs/...` para documentação e `demo/**` para ensaiar o pipeline.
- **Proteção da `main`** (em vigor desde 07/10, por decisão do Allainn como dono do repositório): só recebe mudanças por PR, com 1 aprovação de outro integrante e a aprovação do @Allainn como code owner ([CODEOWNERS](../../.github/CODEOWNERS)). Nos PRs do próprio Allainn, vale só a aprovação do colega ([CONTRIBUTING.md](../../CONTRIBUTING.md#branches-e-commits)).
- **Commits:** Conventional Commits em português, citando o ADR da parte. Ex.: `fix(agendamento): só o cliente que reservou cancela o agendamento (ADR-0010)`.
- **Idioma do código** (votado na Q23): domínio em português (`Agendamento`, `barbearia_id`, `agendamento.criado`) e termos técnicos em inglês (`Repository`, `UseCase`, `Controller`).
- **Repositório público:** o professor acessa sem depender de convite, e os minutos do GitHub Actions são ilimitados ([ADR-0013](0013-entrega-continua-e-observabilidade.md)).

Kubernetes, Minikube e Argo CD ficaram fora pelo [roadmap](../roadmap.md), então não há pasta de manifestos.

## Consequências

- O pipeline usa `paths:` para publicar o barbearia-service só quando ele muda ([ADR-0013](0013-entrega-continua-e-observabilidade.md)).
- Uma mudança que cruza serviços sai num PR só, e o C4 em Mermaid fica junto do código.
- Monorepo não significa deploy único: cada serviço tem o próprio Dockerfile e a própria imagem.
- O CODEOWNERS põe todos os PRs na revisão do Allainn, o que deu a mesma régua para todas as partes. O custo é o Allainn virar gargalo, compensado pela revisão no mesmo dia em que o PR é aberto.
- As permissões não são separadas por serviço: qualquer colaborador pode mexer em qualquer pasta. A divisão é combinada no [tarefas.md](../tarefas.md) ("Arquivos que você pode mexer"), e a revisão confere.

## Referências

- Aula 1 [00:36:55]: três eixos (comunicação, dados, implantação); a implantação é por serviço.
- Aula 5 [00:16:02] e [00:18:14]: entrega pelo link do repositório, com README testado numa máquina limpa.
- NEWMAN, Sam. **Building microservices**. 2. ed. Sebastopol: O'Reilly, 2021. Capítulo sobre organização de código-fonte (monorepo × multirepo).
- Votação da Q23: [issue #23](https://github.com/Allainn/barbearia-multiplataforma/issues/23).
