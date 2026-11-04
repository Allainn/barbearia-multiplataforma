# BarberHub: app mobile (Flutter)

App de agendamento em barbearias do **Grupo 8**, feito como Projeto Final de **Arquitetura de Aplicações Móveis e Multiplataforma** (PUC Minas IEC, prof. Jackson Smith Moisés Matias). É o front do back-end deste monorepo: o app só conversa com o BFF, que valida o token do Keycloak e chama os serviços.

> **Situação (04/11/2026):** esqueleto. Camadas, tema claro e escuro, URL do BFF configurável, cliente HTTP do BFF e telas de carregando/vazio/erro estão prontos. As features entram uma por PR, uma por integrante. Decisões em [ADR.md](ADR.md).

## Features

Proposta do plano; o grupo fecha quem faz cada uma.

| # | Feature | Rota do BFF | Responsável |
|---|---|---|---|
| 1 | Login do cliente | Keycloak (realm `barbearia`) | a definir |
| 2 | Lista de barbearias | `GET /barbearias` | a definir |
| 3 | Detalhe: profissionais e serviços | `GET /barbearias/{id}/profissionais` e `/servicos` | a definir |
| 4 | Busca por nome | `GET /barbearias` | a definir |
| 5 | Filtro | `GET /barbearias` | a definir |
| 6 | Favoritos que sobrevivem a fechar o app | armazenamento local | a definir |
| 7 | Horários livres e reserva, com o 409 | `GET /disponibilidade` e `POST /agendamentos` | a definir |
| 8 | Meus agendamentos e cancelar | `DELETE /agendamentos/{id}` | a definir |

## Como rodar

### 1. Suba o back-end

Na raiz do monorepo (Docker com 8 GB livres; detalhes em [Como rodar](../../README.md#como-rodar)):

```bash
bash scripts/up.sh
```

### 2. Rode o app

Flutter estável **3.47** (o `pubspec.lock` foi gerado com a 3.47.6) e um emulador Android aberto:

```bash
cd apps/barberhub-app
flutter pub get
flutter run
```

### Endereço do back-end

O app lê os endereços do `--dart-define`; sem ele, usa o padrão da plataforma.

| Onde o app roda | O que fazer |
|---|---|
| Emulador Android | nada: o padrão é `http://10.0.2.2:8010`, o computador visto de dentro do emulador |
| Celular no USB | `adb reverse tcp:8010 tcp:8010` e `adb reverse tcp:8080 tcp:8080`, depois `flutter run --dart-define=BFF_URL=http://localhost:8010 --dart-define=KEYCLOAK_URL=http://localhost:8080` |
| Celular no mesmo Wi-Fi | `flutter run --dart-define=BFF_URL=http://<IP do computador>:8010 --dart-define=KEYCLOAK_URL=http://<IP do computador>:8080` |
| Simulador iOS ou navegador | nada: o padrão é `http://localhost:8010`. No navegador as chamadas falham, porque o BFF não tem CORS |

| Variável | Padrão | Uso |
|---|---|---|
| `BFF_URL` | `http://10.0.2.2:8010` (Android) ou `http://localhost:8010` | toda chamada da API |
| `KEYCLOAK_URL` | mesma regra, porta 8080 | login |
| `KEYCLOAK_REALM` | `barbearia` | login |

A tela inicial mostra os endereços em uso, para conferir.

### Usuários de teste

| Usuário | Senha | Role |
|---|---|---|
| `cliente1` | `cliente123` | `cliente` |
| `cliente2` | `cliente123` | `cliente` |
| `gestor1` | `gestor123` | `gestor` |

## Testes e build

Rode os três antes de abrir PR. O build é **critério eliminatório** da disciplina: app que não builda zera a Funcionalidade.

```bash
flutter analyze
flutter test
flutter build apk --debug   # gera build/app/outputs/flutter-apk/app-debug.apk
```

## Arquitetura

```
lib/
├── main.dart              # lê a configuração e monta as dependências
├── app.dart               # MaterialApp: tema claro/escuro, pt-BR, primeira tela
├── core/
│   └── app_config.dart    # BFF_URL, KEYCLOAK_URL e KEYCLOAK_REALM
├── data/                  # fala com o mundo de fora: BFF e armazenamento local
│   ├── bff_client.dart    # único cliente HTTP; põe o token e trata os erros
│   └── api_exception.dart # erro do BFF já traduzido para a tela
├── state/                 # estado das telas
│   └── theme_controller.dart
└── ui/
    ├── theme/app_theme.dart     # cores, espaçamentos e raios num lugar só
    ├── widgets/state_views.dart # LoadingView, EmptyView, ErrorView
    └── screens/home_screen.dart # provisória, sai com a feature de lista
```

Regras para cada feature:

1. **A tela não faz HTTP.** O caminho é tela → estado → repositório em `lib/data/` → `BffClient`. O repositório converte o JSON em modelo (`Barbearia`, `Agendamento`...).
2. **Toda tela com dados mostra carregando, vazio e erro** com os widgets de `state_views.dart`. `ErrorView` já tem texto para sem rede, 401, 403, 404, 409 e 503.
3. **Nada de cor ou espaçamento solto:** use `Theme.of(context).colorScheme`, `AppSpacing` e `AppRadius`.
4. **Pelo menos um teste** da lógica da sua feature em `test/`.
5. Nomes: domínio em português, termos técnicos em inglês (`BarbeariaRepository`, `ReservaScreen`); arquivos Dart em `snake_case`.

O gerenciador de estado ainda não foi escolhido ([ADR.md](ADR.md)). Até lá, as dependências descem pelo construtor a partir do `BarberHubApp`.

## Screenshots

_A fazer: pelo menos 3 (lista, detalhe e reserva, em claro e escuro), quando as features entrarem._

## Como contribuir

Branch `feat/app-<feature>` a partir da `main`, PR com aprovação de um colega e do code owner, commits no padrão `feat(app): lista de barbearias (ADR.md do app)`. Regras gerais no [CONTRIBUTING.md](../../CONTRIBUTING.md).
