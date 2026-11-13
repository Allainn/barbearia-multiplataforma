# ADR-0016: App mobile do cliente em Flutter, no monorepo, consumindo o BFF

- **Status:** Aceito
- **Data:** 04/11/2026
- **Questão:** [Q06](../questoes-abertas.md#q06) · [Q08](../questoes-abertas.md#q08) · issues #6 e #8
- **Afeta no diagrama:** C4 nível 2 (container novo `barberhub-app` entre o Cliente e o BFF; setas Cliente → app, app → BFF e app → Keycloak) e nível 1 (o Cliente usa o app)
- **Relacionado:** [ADR-0004](0004-decomposicao-em-servicos.md) (front-ends fora do diagrama; BFF por canal como evolução) · [ADR-0005](0005-linguagens-por-servico.md) (o Dart saiu do escopo em 21/10) · [ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md) e [ADR-0015](0015-onde-autenticar-e-autorizar.md) (token e onde ele é conferido) · [ADR.md do app](../../apps/barberhub-app/ADR.md) (framework e gerenciador de estado)
- **Aprovações:** _a preencher no merge_

## Contexto

- Na Q06 o grupo votou um front mínimo e, na Q08, Dart com Flutter. O [roadmap](../roadmap.md) de 21/10 cortou os dois, porque o front não era avaliado nesta disciplina ([ADR-0005](0005-linguagens-por-servico.md)).
- Em 26/10, o professor de **Arquitetura de Aplicações Móveis e Multiplataforma** aceitou que o Projeto Final de lá seja o front deste back-end, com os 7 integrantes e uma feature por pessoa. Lá o front vale 30 pontos: UI/UX, camadas, 5 features, testes e build passando (eliminatório). Entrega e demo em 09/11.
- O back-end está pronto e o contrato é fixo ([docs/tarefas.md](../tarefas.md#contrato)): tudo de fora entra pelo BFF (8010), com token do Keycloak.
- O único client do Keycloak é o `bff-gateway`, confidencial. Um app instalado no celular não guarda segredo: é um cliente público.

## Opções consideradas

### A. App no monorepo (`apps/barberhub-app`), consumindo só o BFF existente

- **Prós:** contrato, back-end e app no mesmo PR e no mesmo clone; quem corrige sobe o back-end com `scripts/up.sh` e roda o app na mesma pasta; reaproveita o fluxo de PR, o CODEOWNERS e os ADRs; nenhuma mudança no BFF.
- **Contras:** o monorepo ganha uma terceira linguagem (Dart) e outro tipo de build; o histórico do app se mistura com o do back-end.

### B. App em repositório separado

- **Prós:** CI e histórico próprios; o repo do app fica pequeno para quem só mexe no front.
- **Contras:** o contrato fica num repo e o consumidor em outro; mudança que atravessa os dois vira dois PRs; o professor precisa clonar dois repos para rodar a demo.

### C. BFF próprio para o app (BFF por canal)

- **Prós:** a resposta sai do jeito que a tela precisa (ex.: `GET /app/barbearias?busca=&bairro=` agregando e filtrando no servidor), como o [ADR-0004](0004-decomposicao-em-servicos.md) previu para quando houvesse canais.
- **Contras:** mais um container em Java na semana de entrega; hoje só existe um canal, então o BFF atual já é o BFF do app.

## Decisão

Opção **A**: o app do cliente é um container novo, `barberhub-app`, em Flutter, na pasta `apps/barberhub-app` do monorepo. Ele chama só o BFF (porta 8010, REST com o JWT no header) e o Keycloak para obter o token. Os endereços vêm do `--dart-define` no build, nunca fixos no código.

A escolha do framework (Flutter contra React Native e KMP) e do gerenciador de estado é da outra disciplina e está no [ADR.md do app](../../apps/barberhub-app/ADR.md). Este ADR complementa o 0004 (que deixou os front-ends fora do diagrama) e o 0005 (que tirou o Dart), sem reescrevê-los.

## Consequências

- O C4 nível 2 ganha o container `barberhub-app`; na demo, o Cliente deixa de ser o curl. O gestor continua no curl: as telas do gestor ficaram fora.
- O BFF por canal (opção C) continua como evolução. Volta à mesa se o filtro da lista precisar de dados que o `GET /barbearias` não tem.
- O que precisa ser feito no back-end por causa desta decisão (cada item muda o contrato e é avisado no grupo):
  - **Client público no Keycloak** (ex.: `barberhub-app`), sem secret, com um *audience mapper* que ponha `bff-gateway` no `aud`; sem ele o BFF devolve 401.
  - **Fluxo de login:** Authorization Code com PKCE é o certo para cliente público (RFC 8252), mas o `KC_HOSTNAME` fixo em `http://keycloak:8080` não resolve no navegador do celular. A alternativa é o password grant com o client público, como atalho de demo. Decisão registrada no ADR.md do app.
  - **Seed com mais barbearias**, para a lista, a busca e o filtro fazerem sentido.
  - **`GET /agendamentos`** do cliente, se a feature "meus agendamentos" entrar. Acrescentada em 13/11/2026 no agendamento-service e no BFF (role `cliente`, filtrada pelo `sub` do token); o app ainda guarda as reservas no aparelho até passar a ler dessa rota.
  - **CORS no BFF** só se o app rodar no navegador; no Android não é preciso.
- O CI ganha um workflow para o app (analyze, testes e build do APK em todo PR que mexer em `apps/barberhub-app`).

## Referências

- Projeto Final de Arquitetura de Aplicações Móveis e Multiplataforma: [enunciado](https://github.com/jacksonsmith/puc-iec-mobile-multiplataforma/blob/main/exercicios/projeto-final/enunciado.md) e aceite do professor na aula de 26/10 (02:23:35 e 02:24:51 da gravação).
- DENNISS, W.; BRADLEY, J. *OAuth 2.0 for Native Apps*. RFC 8252. IETF, 2017. Disponível em: <https://www.rfc-editor.org/rfc/rfc8252>.
- NEWMAN, S. *Backends For Frontends*. Disponível em: <https://samnewman.io/patterns/architectural/bff/>.
