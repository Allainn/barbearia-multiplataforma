# ADR-0013: Entrega contínua e observabilidade

- **Status:** Proposto · **depende do conteúdo da Aula 4 (07/10)**
- **Data:** 07/10/2026
- **Questão:** [Q19](../questoes-abertas.md#q19) · [Q20](../questoes-abertas.md#q20)
- **Afeta no diagrama:** C4 nível 2 (stack de observabilidade, se o grupo decidir mostrá-la); diagrama de implantação, se fizermos um

## Contexto

- A demo precisa mostrar o fluxo inteiro: **código alterado → pipeline → publicação → chamada no endpoint → tempo da chamada no Grafana** (Aula 3 · P3 [01:07:32]).
- O professor antecipou: Docker, Kubernetes via **Minikube**, GitOps, registry e build locais, sem nuvem paga; ferramentas citadas: Argo (CD) e Woodpecker (CI); talvez um exemplo de GitLab CI, que dá para converter para GitHub Actions.
- O repositório está no GitHub. Os runners do GitHub Actions rodam na nuvem e **não alcançam** o Minikube na máquina de quem apresenta.
- O PizzaExpress já tem OpenTelemetry em todos os serviços e a stack Prometheus, Loki, Tempo, OTel Collector e Grafana com dashboards.

## Opções consideradas (CI/CD)

### A. GitHub Actions (CI) + GHCR (registry) + Argo CD no Minikube (CD por GitOps)

O Actions testa, constrói e publica a imagem no GHCR e atualiza a tag no manifesto em `infra/k8s/`. O Argo CD, rodando no Minikube, **puxa** a mudança do Git e aplica.

- **Prós:** o modelo pull do GitOps resolve o problema de alcance (o cluster local busca no GitHub); é o fluxo que o professor vai ensinar; tudo gratuito.
- **Contras:** Argo CD consome RAM; o pipeline precisa de permissão para commitar a nova tag no repositório. Como o repositório é público, as imagens no GHCR também podem ser públicas, sem `imagePullSecret` no Minikube.

### B. GitHub Actions com runner self-hosted na máquina de quem apresenta + `docker compose`

- **Prós:** mais simples; sem Kubernetes.
- **Contras:** foge do Kubernetes/GitOps da Aula 4; o runner depende de uma máquina específica ligada.

### C. Woodpecker CI ou GitLab CI local

- **Prós:** tudo local, como o professor sugeriu.
- **Contras:** mais infraestrutura para subir e manter; o repositório já está no GitHub.

## Opções consideradas (observabilidade)

**Reaproveitar a stack do PizzaExpress** (proposta): SDK OpenTelemetry em cada serviço → OTel Collector → Tempo (traces), Prometheus (métricas), Loki (logs) → Grafana. O desafio extra é **propagar o trace pelo Kafka** (header `traceparent`), para um único trace mostrar BFF → agendamento → Kafka → notificação.

## Decisão

**Proposta preliminar:** opção A para CI/CD e a stack do PizzaExpress para observabilidade. **Revisar depois da Aula 4**, com o exemplo que o professor trouxer.

## Consequências

- Um workflow por serviço com filtro de `paths:` ([ADR-0002](0002-monorepo-e-estrutura.md)).
- Manifestos Kubernetes em `infra/k8s/` (Kustomize ou Helm, a decidir).
- Dashboard do Grafana com latência por endpoint e o trace distribuído da reserva.

## Perguntas para o grupo

- O que a Aula 4 mostrou muda esta proposta (ferramenta de CI, Argo CD, registry)?
- Minikube na apresentação, ou `docker compose` com o pipeline publicando as imagens?
- Quem cuida da infraestrutura e do pipeline ([Q22](../questoes-abertas.md#q22))?

## Referências

- Aula 3 · P3 [01:00:42]–[01:08:11]: antecipação da Aula 4 (CI/CD, Minikube, GitOps, Argo, observabilidade).
- HUMBLE, Jez; FARLEY, David. **Continuous delivery**. Addison-Wesley, 2010.
- ARGO PROJECT. **Argo CD**. Disponível em: <https://argo-cd.readthedocs.io/>.
- OPENTELEMETRY. **Documentation**. Disponível em: <https://opentelemetry.io/docs/>.
