# ADR-0002: Monorepo e estrutura de pastas

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q23](../questoes-abertas.md#q23)
- **Afeta no diagrama:** nenhum elemento; cada container do C4 nível 2 vira uma pasta em `services/`

## Contexto

- Vamos ter de 4 a 6 serviços em pelo menos 2 linguagens, além da infraestrutura (Keycloak, Kafka, Postgres, stack de observabilidade) e da documentação.
- A demo precisa subir tudo de uma vez (`docker compose up` ou Minikube) e o pipeline de CI/CD precisa publicar cada serviço.
- O professor e o grupo precisam encontrar tudo num lugar só.

## Opções consideradas

### A. Monorepo (um repositório com serviços, infraestrutura e documentação)

- **Prós:** um único `docker-compose`/manifesto para subir o ambiente; ADRs junto do código; mudanças que cruzam serviços (ex.: contrato de evento) num único PR; o agente de IA enxerga tudo.
- **Contras:** o CI precisa de filtro por pasta para não rebuildar tudo; permissões não são separadas por serviço.

### B. Um repositório por serviço (polyrepo)

- **Prós:** independência real de deploy e de permissões; espelha times separados.
- **Contras:** para 3 semanas e 7 pessoas é sobrecarga: 6+ repositórios, contratos duplicados, ambiente montado com vários clones.

## Decisão

**Proposta:** opção A, com esta estrutura:

```
.
├── docs/            # enunciado, ADRs, questões, arquitetura (C4)
├── services/
│   ├── bff-gateway/
│   ├── barbearia-service/
│   ├── agendamento-service/
│   ├── disponibilidade-service/
│   └── notificacao-service/
├── contracts/       # contratos de eventos (JSON Schema / AsyncAPI) e OpenAPI
├── infra/
│   ├── compose/     # docker-compose do ambiente local
│   ├── k8s/         # manifestos (se o ADR-0013 aprovar Kubernetes)
│   ├── keycloak/    # seed do realm
│   └── observabilidade/
├── scripts/         # demos com curl, seed de dados
└── .github/         # templates e workflows
```

Os nomes dos serviços dependem do [ADR-0004](0004-decomposicao-em-servicos.md) e da convenção de idioma ([Q23](../questoes-abertas.md#q23)).

Convenções propostas: `main` protegida, branches `adr/`, `feat/`, `fix/`, `docs/`, `infra/`, commits no padrão Conventional Commits.

> **Já em vigor (07/10/2026), por decisão do Allainn como dono do repositório:** a `main` só recebe mudanças por PR, com 1 aprovação de outro integrante e aprovação do @Allainn via [CODEOWNERS](../../.github/CODEOWNERS). Detalhes em [CONTRIBUTING.md](../../CONTRIBUTING.md#branches-e-commits).

## Consequências

- O CI usa `paths:` por serviço para construir só o que mudou.
- Os contratos de eventos ficam em `contracts/`, fora dos serviços, porque são compartilhados entre linguagens.
- Monorepo não significa deploy único: cada serviço continua com imagem e versão próprias.

## Perguntas para o grupo

- Nome final do repositório e do produto ([Q02](../questoes-abertas.md#q02)).
- Os nomes do código ficam em português ou em inglês ([Q23](../questoes-abertas.md#q23))?

## Referências

- Aula 1 [00:36:55]: três eixos (comunicação, dados, implantação); a implantação é por serviço.
- NEWMAN, Sam. **Building microservices**. 2. ed. O'Reilly, 2021. Capítulo sobre organização de código-fonte (monorepo x multirepo).
