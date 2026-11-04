# BarberHub: app mobile (Flutter)

App de agendamento em barbearias do **Grupo 8**, feito como Projeto Final de **Arquitetura de Aplicações Móveis e Multiplataforma** (PUC Minas IEC, prof. Jackson Smith Moisés Matias). É o front do back-end deste monorepo: o app só conversa com o BFF, que valida o token do Keycloak e chama os serviços.

> **Situação (04/11/2026):** base pronta, features a fazer. Já existem: camadas, navegação por abas, modelos do contrato, cliente HTTP do BFF, design (fontes, paleta, componentes e um guia visual), tema claro e escuro, ícone, splash e CI. As features entram uma por PR, uma por integrante. Decisões em [ADR.md](ADR.md) (framework e estado) e no [ADR-0016](../../docs/adr/0016-app-mobile-flutter.md) do monorepo (como o app entra na arquitetura).

## Features

Proposta do plano; o grupo fecha quem faz cada uma.

| # | Feature | Onde entra | Rota do BFF | Responsável |
|---|---|---|---|---|
| 1 | Login do cliente | aba Conta | Keycloak (realm `barbearia`) | a definir |
| 2 | Lista de barbearias | aba Barbearias | `GET /barbearias` | a definir |
| 3 | Detalhe: profissionais e serviços | tela por cima da lista | `GET /barbearias/{id}/profissionais` e `/servicos` | a definir |
| 4 | Busca por nome | aba Barbearias | `GET /barbearias` | a definir |
| 5 | Filtro | aba Barbearias | `GET /barbearias` | a definir |
| 6 | Favoritos que sobrevivem a fechar o app | aba Favoritos | armazenamento local | a definir |
| 7 | Horários livres e reserva, com o 409 | a partir do detalhe | `GET /disponibilidade` e `POST /agendamentos` | a definir |
| 8 | Meus agendamentos e cancelar | aba Agendamentos | `DELETE /agendamentos/{id}` | a definir |

## Como rodar

### 1. Suba o back-end

Na raiz do monorepo (Docker com 8 GB livres; detalhes em [Como rodar](../../README.md#como-rodar)):

```bash
bash scripts/up.sh
```

### 2. Rode o app

Flutter estável **3.47** (o `pubspec.lock` foi gerado com a 3.47.6) e um emulador Android aberto. Com Flutter anterior à 3.44, o `pub get` reescreve o `pubspec.lock`: rode `flutter upgrade` em vez de commitar essa mudança.

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

A aba **Conta** mostra os endereços em uso, para conferir.

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

O GitHub Actions ([barberhub-app.yml](../../.github/workflows/barberhub-app.yml)) roda os três em todo PR que mexe em `apps/barberhub-app/` e guarda o APK como artefato da execução por 7 dias: dá para instalar no celular sem ter o Android SDK.

## Arquitetura

```
lib/
├── main.dart                  # lê a configuração e monta as dependências
├── app.dart                   # MaterialApp: tema claro/escuro, pt-BR, abas
├── core/
│   ├── app_config.dart        # BFF_URL, KEYCLOAK_URL e KEYCLOAK_REALM
│   └── formatters.dart        # hora, dia, preço e duração; datas no fuso -03:00
├── data/                      # fala com o mundo de fora: BFF e armazenamento local
│   ├── bff_client.dart        # único cliente HTTP; põe o token e trata os erros
│   ├── api_exception.dart     # erro do BFF já traduzido para a tela
│   └── models/                # Barbearia, Profissional, Servico, Disponibilidade, Agendamento
├── state/                     # estado das telas
│   └── theme_controller.dart
└── ui/
    ├── theme/app_theme.dart   # cores, fontes, espaçamentos e raios num lugar só
    ├── widgets/               # LoadingView/EmptyView/ErrorView, SkeletonList, Monogram, InfoChip, SectionHeader
    └── screens/
        ├── shell_screen.dart        # as quatro abas
        ├── placeholder_screen.dart  # "em construção": cada feature troca pela sua tela
        ├── conta_screen.dart        # login (a fazer), tema, back-end e guia visual
        └── guia_visual_screen.dart  # catálogo do visual para o grupo
```

Regras para cada feature:

1. **A tela não faz HTTP.** O caminho é tela → estado → repositório em `lib/data/` → `BffClient`. O repositório converte o JSON em modelo (`Barbearia`, `Agendamento`...).
2. **Use os modelos de `lib/data/models/`**, que já leem o JSON do contrato. Se faltar um campo, ajuste o modelo e o teste dele em vez de criar outra classe.
3. **Toda tela com dados mostra carregando, vazio e erro.** Lista carregando usa `SkeletonList`; o resto, `LoadingView`, `EmptyView` e `ErrorView`. O `ErrorView` já tem texto para sem rede, 401, 403, 404, 409 e 503.
4. **Copie o visual do Guia visual** (aba Conta → Guia visual): cartão de lista, chips, botões. Nada de cor ou espaçamento solto: `Theme.of(context).colorScheme`, `AppSpacing` e `AppRadius`.
5. **Hora e data sempre pelos formatadores** (`formatHora`, `formatDia`). Eles mostram o horário da barbearia (-03:00) mesmo com o emulador em outro fuso.
6. **Pelo menos um teste** da lógica da sua feature em `test/`.
7. Nomes: domínio em português, termos técnicos em inglês (`BarbeariaRepository`, `ReservaScreen`); arquivos Dart em `snake_case`.

### Design

- **Fontes:** Manrope no texto e DM Serif Display nos títulos grandes, embarcadas em `assets/fonts/` (licença OFL), então funcionam sem internet.
- **Cores:** azul-marinho como `primary` e latão como `tertiary` (favorito, preço, destaques), geradas pelo Material 3 nos temas claro e escuro.
- **Ícone e splash:** a arte fica em `assets/icon/` (SVG e PNG). Se ela mudar, gere de novo com `dart run flutter_launcher_icons` e `dart run flutter_native_splash:create`.

O gerenciador de estado ainda não foi escolhido ([ADR.md](ADR.md)). Até lá, as dependências descem pelo construtor a partir do `BarberHubApp`.

## Screenshots

_A fazer: pelo menos 3 (lista, detalhe e reserva, em claro e escuro), quando as features entrarem._

## Como contribuir

Branch `feat/app-<feature>` a partir da `main`, PR com aprovação de um colega e do code owner, commits no padrão `feat(app): lista de barbearias (ADR-0016)`. Regras gerais no [CONTRIBUTING.md](../../CONTRIBUTING.md).
