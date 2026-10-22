# ADR-0013: Entrega contínua e observabilidade

- **Status:** Aceito
- **Data:** 22/10/2026
- **Questão:** [Q19](../questoes-abertas.md#q19) · [Q20](../questoes-abertas.md#q20)
- **Afeta no diagrama:** C4 nível 2 (stack de observabilidade, se o grupo decidir mostrá-la); diagrama de implantação, se fizermos um

## Contexto

- A demo precisa mostrar o fluxo inteiro: **código alterado → pipeline → publicação → chamada no endpoint → tempo da chamada no Grafana** (Aula 3 · P3 [01:07:32]).
- O professor antecipou: Docker, Kubernetes via **Minikube**, GitOps, registry e build locais, sem nuvem paga; ferramentas citadas: Argo (CD) e Woodpecker (CI); talvez um exemplo de GitLab CI, que dá para converter para GitHub Actions.
- O repositório está no GitHub. Os runners do GitHub Actions rodam na nuvem e **não alcançam** o Minikube na máquina de quem apresenta.
- O PizzaExpress já tem OpenTelemetry em todos os serviços e a stack Prometheus, Loki, Tempo, OTel Collector e Grafana com dashboards.

## Opções consideradas (CI/CD)

### A. GitHub Actions (CI) + GHCR (registry) + Docker Compose (CD local)

O Actions constrói e publica a imagem do `barbearia-service` no GHCR. A máquina da apresentação executa `docker compose pull` e recria o serviço com a nova imagem.

- **Prós:** implementação simples, compatível com a infraestrutura já executada em Docker Compose e adequada ao limite de memória das máquinas.
- **Contras:** não demonstra GitOps nem Kubernetes; o deploy depende da máquina local estar ligada e autenticada no GHCR.

### B. GitHub Actions com runner self-hosted na máquina de quem apresenta + `docker compose`

- **Prós:** mais simples; sem Kubernetes.
- **Contras:** foge do Kubernetes/GitOps da Aula 4; o runner depende de uma máquina específica ligada.

### C. Woodpecker CI ou GitLab CI local

- **Prós:** tudo local, como o professor sugeriu.
- **Contras:** mais infraestrutura para subir e manter; o repositório já está no GitHub.

## Opções consideradas (observabilidade)

**Reaproveitar a stack do PizzaExpress** (proposta): SDK OpenTelemetry em cada serviço → OTel Collector → Tempo (traces), Prometheus (métricas), Loki (logs) → Grafana. O desafio extra é **propagar o trace pelo Kafka** (header `traceparent`), para um único trace mostrar BFF → agendamento → Kafka → notificação.

## Decisão

**Decisão:** opção A para CI/CD, com GitHub Actions publicando no GHCR e deploy local via Docker Compose. A stack de observabilidade do PizzaExpress foi mantida e adaptada para os nomes dos containers da Barbearia.

O workflow [`barbearia-service.yml`](../../.github/workflows/barbearia-service.yml) dispara em `main`, em branches `demo/**` quando o serviço muda, e manualmente. Publica as tags `latest` e o SHA do commit. O deploy é feito por [`scripts/deploy.sh`](../../scripts/deploy.sh).

## Consequências

- O workflow usa um filtro de `paths:` para evitar builds quando o `barbearia-service` não foi alterado.
- O deploy local baixa a imagem publicada e recria somente o `barbearia-service`; os demais containers continuam sob o Docker Compose da infraestrutura.
- O Grafana apresenta a latência por endpoint e as métricas, logs e traces coletados pela stack OpenTelemetry, Prometheus, Loki e Tempo.
- Argo CD, Minikube, Kubernetes e runner self-hosted ficaram fora do escopo por prazo e por custo operacional.
- A propagação de trace pelo Kafka não é requisito desta entrega; os eventos continuam observáveis nos serviços produtores e consumidores.

## Referências

- Aula 3 · P3 [01:00:42]–[01:08:11]: antecipação da Aula 4 (CI/CD, Minikube, GitOps, Argo, observabilidade).
- HUMBLE, Jez; FARLEY, David. **Continuous delivery**. Addison-Wesley, 2010.
- ARGO PROJECT. **Argo CD**. Disponível em: <https://argo-cd.readthedocs.io/>.
- OPENTELEMETRY. **Documentation**. Disponível em: <https://opentelemetry.io/docs/>.
