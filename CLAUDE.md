# CLAUDE.md

Contexto e regras para o Claude Code (e para qualquer agente) que trabalhar neste repositório.

## Sobre o projeto

Trabalho final em grupo da disciplina **Arquitetura de Software Multiplataforma** (PUC Minas, prof. Messias Barbosa Bittencourt). Plataforma multi-tenant de agendamento para barbearias. Vale 100 pontos; apresentação de 20 minutos em **28/10/2026**.

O que o professor avalia: **integrações entre plataformas funcionando** e **justificativa das decisões arquiteturais**. Regras de negócio, front-end e qualidade fina de código não são avaliados. Regras completas em [docs/enunciado.md](docs/enunciado.md).

**Segunda fase (desde 31/10/2026): o app mobile.** O mesmo grupo faz o front do BarberHub em Flutter, em [apps/barberhub-app](apps/barberhub-app/README.md), como Projeto Final de **Arquitetura de Aplicações Móveis e Multiplataforma** (prof. Jackson Smith Moisés Matias, 30 pontos, demo ao vivo em **09/11/2026**). Lá o front é avaliado: UI/UX, camadas, 5 features, estados de carregando/vazio/erro, testes, README e build passando (eliminatório). Regras em [enunciado do Projeto Final](https://github.com/jacksonsmith/puc-iec-mobile-multiplataforma/blob/main/exercicios/projeto-final/enunciado.md) e na seção [App mobile](#app-mobile-appsbarberhub-app) abaixo.

## O que vale para implementar (desde 21/10/2026)

O escopo, o contrato e a parte de cada pessoa estão em dois documentos, que **valem mais do que qualquer outro arquivo deste repositório**:

- [docs/roadmap.md](docs/roadmap.md): resumo, contrato e datas.
- [docs/tarefas.md](docs/tarefas.md): passo a passo de cada pessoa, com variáveis de ambiente, tabelas e testes de aceite. **Comece pela seção "Para a IA que está lendo este arquivo".**

Os ADRs em [docs/adr](docs/adr/README.md) registram cada decisão com as alternativas consideradas. Cada pessoa passa o ADR da sua parte para *Aceito* no mesmo PR do código, com o que foi implementado; os gerais (0001 a 0005) são do Allainn. A situação de cada um está no [índice](docs/adr/README.md).

## Regras de trabalho para o agente

Valem para o back-end (`services/`, `infra/`, `scripts/`, `docs/`). No app, valem as regras 2, 5, 6 e 9 e mais as da seção [App mobile](#app-mobile-appsbarberhub-app).

1. **Trabalhe só na parte da pessoa** com quem você está falando (pergunte o nome se não souber) e só nos arquivos da lista "Arquivos que você pode mexer" da seção dela em `docs/tarefas.md`.
2. **O contrato é fixo.** Se algo nele for impossível de cumprir, pare e diga à pessoa para avisar o grupo antes de mudar qualquer coisa.
3. **O que está em "Fora do escopo" fica fora**, mesmo que pareça fácil.
4. **Prefira copiar e adaptar o código do PizzaExpress** a escrever do zero, seguindo as regras de `docs/tarefas.md` (OpenTelemetry mantido, nomes do nosso domínio, rotas sem barra no final).
5. **Não abra issues.** A fase de questões (issues #1 a #24) terminou.
6. **Nunca commite na `main`.** Ela é protegida: trabalhe na branch `feat/<sua-parte>` e abra PR. O merge exige 1 aprovação de outro integrante e a aprovação do @Allainn (code owner). Detalhes em [CONTRIBUTING.md](CONTRIBUTING.md).
7. **Commits citam o ADR** da parte, no padrão Conventional Commits em português. Ex.: `feat(agendamento): reserva com constraint de exclusão (ADR-0007)`.
8. **Não edite `docs/adr/README.md`**: o índice é do Allainn.
9. **Diagrama C4 e código andam juntos.** Se a sua parte criar ou remover um container, tópico ou seta, avise a pessoa para contar ao Allainn, que atualiza o C4.

## App mobile (`apps/barberhub-app`)

Comece pelo [README](apps/barberhub-app/README.md) do app (como rodar, camadas, regras de cada feature), pelo [ADR.md](apps/barberhub-app/ADR.md) e pelo [ADR-0016](docs/adr/0016-app-mobile-flutter.md).

1. **Uma feature por pessoa.** Trabalhe só na feature da pessoa com quem você está falando (pergunte o nome se não souber). A tabela de features e responsáveis fica no README do app.
2. **Só dentro de `apps/barberhub-app/`.** Mudança em `lib/core/`, no tema ou nos widgets de estado afeta todo mundo: avise a pessoa para combinar com o grupo antes.
3. **O app só fala com o BFF** (porta 8010), pelo `BffClient`. O que o app precisar do back-end (client público no Keycloak, seed com mais barbearias, `GET /agendamentos`) muda o contrato: pare e peça para a pessoa avisar o grupo.
4. **Sem biblioteca nova de estado ou de navegação** até o grupo decidir e registrar no `ADR.md`. Outras dependências entram no PR da feature, com o motivo na descrição.
5. **Antes de abrir PR:** `flutter analyze`, `flutter test` e `flutter build apk --debug` passando, dentro de `apps/barberhub-app`. O build quebrado zera a Funcionalidade na avaliação.
6. **Branch e commits:** `feat/app-<feature>` (ex.: `feat/app-favoritos`); commits `feat(app): favoritos persistidos (ADR-0016)`. Cada integrante commita a própria feature: a avaliação conta commits e PRs por pessoa.
7. **Nunca commite chave, senha ou token**, nem URL de máquina pessoal no código: endereços vêm do `--dart-define`.

## Estrutura

```
.
├── docs/
│   ├── roadmap.md              # plano até 28/10: escopo, contrato, datas
│   ├── tarefas.md              # passo a passo por pessoa (para entregar à IA de cada um)
│   ├── enunciado.md            # regras do professor, checklist
│   ├── adr/                    # ADRs numerados; cada dono passa o seu para Aceito no PR
│   ├── arquitetura/            # link do Miro e espelho Mermaid do C4
│   └── questoes-abertas.md     # histórico das questões votadas de 07 a 09/10
├── apps/
│   └── barberhub-app/          # app Flutter (Projeto Final da outra disciplina), com README.md e ADR.md
├── services/                   # um diretório por container, cada um com o próprio Dockerfile
├── infra/                      # docker-compose, config do Postgres, Kafka, Keycloak e Grafana
├── scripts/                    # up, down, deploy, seed do Keycloak, disputa e demo
└── .github/                    # CODEOWNERS, template de PR e workflows de CI
```

## Convenções

- **Idioma:** documentação em português (pt-BR). No código, o domínio fica em português (`Agendamento`, `agendamento.criado`) e os termos técnicos em inglês (`Repository`, `UseCase`, `Controller`), como votado na Q23.
- **Nomes de arquivo:** minúsculas, com hífen, sem acentos. Exceção: arquivos Dart do app usam `snake_case` (`barbearia_repository.dart`), como o Dart exige.
- **ADRs:** formato de [docs/adr/0000-template.md](docs/adr/0000-template.md). Ao aceitar o ADR da sua parte: status *Aceito*, data do PR, seção "Decisão" com o que foi implementado de fato, seção "Perguntas para o grupo" apagada e opções consideradas mantidas.

## Referência de implementação

O PizzaExpress do professor (pacote `pizzaexpress-ambiente.zip` do Canvas) é a base de código a reaproveitar. Ele **não** é o tema. A tabela "Containers" de `docs/tarefas.md` diz de qual serviço do PizzaExpress cada container é copiado.
