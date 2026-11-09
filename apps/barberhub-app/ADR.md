# ADR-0001: Flutter para o app mobile do BarberHub

## Status

`Aceito`. Framework em 31/10; gerenciador de estado e fluxo de login em 09/11 (seções no fim).

**Data:** 2026-10-31 (registrado em 2026-11-04; estado e login em 2026-11-09)
**Autor:** Allainn Christiam Jacinto Tavares, pelo Grupo 8. Seções de estado e login: Evandro Junior, no PR do login
**Origem:** votação Q08 da disciplina Arquitetura de Software Multiplataforma ([issue #8](https://github.com/Allainn/barbearia-multiplataforma/issues/8)), que escolheu Dart/Flutter para o front cortado do back-end por prazo. Como o app entra na arquitetura do back-end (container novo, só o BFF, pendências no Keycloak): [ADR-0016](../../docs/adr/0016-app-mobile-flutter.md)

## Contexto

- **Produto:** front mobile do BarberHub, plataforma multi-tenant de agendamento em barbearias. O back-end já está pronto neste monorepo: um BFF (porta 8010) na frente de quatro serviços, com token do Keycloak ([docs/adr](../../docs/adr/README.md)). O app só fala com o BFF.
- **Uso:** a busca de horários é a operação dominante (50 consultas por agendamento no [ADR-0003](../../docs/adr/0003-enquadramento-plataforma-multi-tenant.md)); a reserva disputada devolve 409, que a tela precisa explicar.
- **Time:** 7 integrantes com perfil de back-end (Java e Python), uma feature por pessoa. Todos fizeram uma atividade em React Native (A2), Flutter (A3) e KMP (A5).
- **Prazo:** uma semana (31/10 a 09/11), com demo ao vivo no emulador Android.
- **Avaliação:** o build de entrega é eliminatório; UI/UX vale 8 dos 30 pontos. O enunciado aceita só Flutter, React Native ou KMP Compose.
- **Login:** o app é um cliente público, sem secret; o fluxo indicado é Authorization Code com PKCE (RFC 8252).

## Decisão

Adotaremos **Flutter** (Dart, Material 3), porque desenha a mesma tela no Android e no iOS, gera o build de entrega com um comando e tem biblioteca madura para o login PKCE.

## Alternativas consideradas

| Alternativa | Prós | Contras |
|---|---|---|
| **Flutter** (escolhida) | O motor desenha a UI: tela igual nas duas plataformas; Material 3 com tema claro e escuro gerados de uma cor; `flutter build apk --debug` direto; PKCE com `flutter_appauth`; Cross-OS 9 e time-to-market 8 na matriz da Aula 1 | Dart é uma linguagem a mais para o time; APK maior (motor e runtime embarcados); no iOS o visual não é o Cupertino |
| React Native + Expo | Ecossistema JS grande; Expo Go roda no celular sem build; componentes nativos de cada plataforma | Build de entrega pede `expo prebuild` + Gradle, mais um ponto de falha no critério eliminatório; o visual muda entre Android e iOS |
| KMP + Compose Multiplatform | Kotlin, perto do Java do BFF; compartilha lógica com código nativo | Ecossistema mais novo (talent pool 5 e tooling 7 na matriz da Aula 1); sem lib OIDC/PKCE multiplataforma madura; Gradle mais pesado |
| Nativo (Kotlin + Swift) ou PWA | Melhor UX nativa; PWA sem loja | Fora do enunciado. Nativo seriam dois códigos em uma semana; PWA não gera APK |

## Consequências

**Positivas:**
- Um código, um build de um comando e o tema num lugar só (`lib/ui/theme/app_theme.dart`).
- Camadas separadas desde o esqueleto: `core` (configuração), `data` (um cliente HTTP para o BFF que já traduz `{"detail"}`, 401, 403, 409 e 503 em erro de tela), `state` e `ui`, com telas padrão de carregando, vazio e erro.
- A URL do BFF vem do `--dart-define`; o mesmo APK aponta para o emulador ou para a máquina da demo sem mudar código.

**Negativas:**
- O time aprende Dart e o modelo de widgets durante a semana de entrega.
- O PKCE esbarra no `KC_HOSTNAME` fixo em `http://keycloak:8080` (o navegador do celular não resolve esse nome). A demo usa o password grant com um client público (seção "Login").
- Web não é alvo: o BFF não tem CORS, e o app no navegador cai no estado "Sem conexão".

## Gerenciador de estado: `ChangeNotifier` do Flutter (`Aceito`, 09/11)

O app não usa biblioteca de estado. Cada feature tem um controller que estende `ChangeNotifier` (`lib/state/`), e a tela escuta com `ListenableBuilder`. O que vem de fora fica num `AsyncState<T>` selado (`AsyncLoading`, `AsyncData`, `AsyncError`): a tela faz um `switch` e o compilador exige os três casos, que é a garantia que o `AsyncValue` do Riverpod daria. As dependências descem pelo construtor a partir de `AppDependencies` (`lib/app_dependencies.dart`), a raiz de composição.

| Opção | A favor | Contra |
|---|---|---|
| **`ChangeNotifier` + `ListenableBuilder`** (escolhida) | Já vem no Flutter: nenhuma dependência nova no build eliminatório; o esqueleto já usava (`ThemeController`); controller testável sem widget; um conceito só para quem vem do back-end | Carregando e erro são modelados à mão (resolvido com o `AsyncState`); injeção manual pelo construtor; sem `select`: quem escuta o controller reconstrói a cada aviso, o que não pesa em telas deste tamanho |
| Riverpod | Usado na A3; `AsyncValue` pronto; providers substituíveis no teste; "recomendação atual" na Aula 3 | Trocar a injeção por `ProviderScope` e ensinar `ref` e os tipos de provider no dia da entrega; mais uma dependência com geração de código opcional |
| Provider | `ChangeNotifier` com injeção pela árvore de widgets | A Aula 3 o trata como legado; ganho pequeno sobre o construtor num app de quatro abas |
| Bloc | Eventos → estados num padrão rígido | Mais código por feature; curva maior para uma semana |

Quando rever: se as telas passarem a compartilhar muito estado derivado ou a injeção pelo construtor atravessar mais de dois níveis, o Riverpod volta à mesa.

## Login: password grant com client público (`Aceito`, 09/11)

O app pede o token direto ao Keycloak (`lib/data/auth_repository.dart`), com o client público `barberhub-app` criado pelo `scripts/keycloak_seed.py`, e manda o access token em toda chamada ao BFF. É a única chamada que não passa pelo BFF, como o [ADR-0016](../../docs/adr/0016-app-mobile-flutter.md) previu.

| Opção | A favor | Contra |
|---|---|---|
| **Password grant (ROPC) com client público** (escolhida) | Funciona com o Keycloak e o BFF como estão: o `iss` continua `http://keycloak:8080`, e o mapper de audience põe `bff-gateway` no `aud`; nenhuma configuração nativa | É antipadrão: a senha passa pelo app, e o OAuth 2.1 retira esse fluxo. Só se justifica como atalho de demo com usuários de teste |
| Authorization Code + PKCE (`flutter_appauth`) | O fluxo certo para cliente público (RFC 8252): a senha só é digitada na página do Keycloak | O navegador do celular não resolve `keycloak:8080`; exige mudar o `KC_HOSTNAME` do compose ou o BFF aceitar dois issuers, mais o esquema de redirect no Android |
| Client `bff-gateway` com o secret no app | Zero mudança no back-end | O secret sai do APK com qualquer descompilador; um client confidencial em app instalado deixa de ser confidencial |

Consequências: a sessão fica só na memória (fechar o app pede o login de novo), porque guardar o refresh token com segurança pede `flutter_secure_storage` e configuração nativa; o access token dura 30 minutos e o `AuthController` renova com o refresh token antes de vencer. Evolução: PKCE, quando o Keycloak tiver um hostname que o celular resolva.

## Meus agendamentos e favoritos no aparelho (`Aceito`, 09/11)

O contrato do back-end tem `POST /agendamentos` e `DELETE /agendamentos/{id}`, mas não tem rota para listar as reservas do cliente, nem favoritos. O app guarda os dois em `shared_preferences`: a resposta 201 de cada reserva, com os nomes que estavam na tela (`ReservaLocal`), e a barbearia inteira de cada favorito. O cancelamento continua indo ao BFF.

| Opção | A favor | Contra |
|---|---|---|
| **Guardar no aparelho** (escolhida) | Não muda o contrato nem dois serviços Java no dia da entrega; as abas abrem sem rede; o cancelamento é o `DELETE` real | A aba só mostra reservas feitas neste aparelho: trocar de celular, ou reservar pelo `curl`, não aparece; o aparelho não fica sabendo de um cancelamento feito por fora |
| `GET /agendamentos` no agendamento-service e no BFF | O servidor é a fonte da verdade; funciona em qualquer aparelho | Rota nova em dois serviços, filtro por `X-User-ID`, revisão e rebuild na véspera da demo |
| Cortar a feature | Nenhum risco | O cliente reserva e não tem onde ver nem cancelar |

Mitigações: as reservas são filtradas pelo `sub` do token, então duas contas no mesmo aparelho não veem as reservas uma da outra; um `DELETE` que volta 404 (reserva que não existe mais no servidor) marca a reserva como cancelada em vez de travar a tela. Evolução: `GET /agendamentos` no contrato, com o aparelho virando só cache.

## Referências

- FLUTTER. *Flutter documentation*. Google, 2026. Disponível em: https://docs.flutter.dev. Acesso em: 4 nov. 2026.
- GOOGLE. *Material Design 3*. Disponível em: https://m3.material.io. Acesso em: 4 nov. 2026.
- DENNISS, W.; BRADLEY, J. *OAuth 2.0 for Native Apps*. RFC 8252. IETF, 2017. Disponível em: https://www.rfc-editor.org/rfc/rfc8252. Acesso em: 4 nov. 2026.
- EXPO. *Prebuild*. Disponível em: https://docs.expo.dev/workflow/prebuild/. Acesso em: 4 nov. 2026.
- JETBRAINS. *Compose Multiplatform*. Disponível em: https://www.jetbrains.com/compose-multiplatform/. Acesso em: 4 nov. 2026.
- MATIAS, J. S. M. *Aula 1: Fundamentos & Panorama Mobile/Multiplataforma* e *Aula 3: Flutter a fundo*. Slides de Arquitetura de Aplicações Móveis e Multiplataforma. PUC Minas IEC, 2026.
