# ADR-0001: Flutter para o app mobile do BarberHub

## Status

`Aceito` para o framework. Gerenciador de estado: `Proposto`, em aberto no grupo (seção no fim). Fluxo de login: em aberto (ver Consequências).

**Data:** 2026-10-31 (registrado em 2026-11-04)
**Autor:** Allainn Christiam Jacinto Tavares, pelo Grupo 8
**Origem:** votação Q08 da disciplina Arquitetura de Software Multiplataforma ([issue #8](https://github.com/Allainn/barbearia-multiplataforma/issues/8)), que escolheu Dart/Flutter para o front cortado do back-end por prazo

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
- O PKCE esbarra no `KC_HOSTNAME` fixo em `http://keycloak:8080` (o navegador do celular não resolve esse nome): ou muda a configuração do Keycloak, ou a demo usa o password grant com um client público.
- Web não é alvo: o BFF não tem CORS, e o app no navegador cai no estado "Sem conexão".

## Gerenciador de estado (`Proposto`)

O esqueleto não usa biblioteca: o tema fica num `ValueNotifier` do Flutter e as dependências descem pelo construtor. Falta o grupo escolher, antes das features:

| Opção | A favor | Contra |
|---|---|---|
| Riverpod | Usado na A3; `AsyncValue` já separa carregando, erro e dados; provider testável sem widget; "recomendação atual" na Aula 3 | Mais conceitos (`ref`, tipos de provider) |
| Provider | O mais simples; `ChangeNotifier` | Carregando e erro feitos à mão em cada tela; a Aula 3 o trata como legado |
| Bloc | Eventos → estados num padrão rígido, código parecido entre 7 pessoas | Mais código por feature; curva maior para uma semana |

## Referências

- FLUTTER. *Flutter documentation*. Google, 2026. Disponível em: https://docs.flutter.dev. Acesso em: 4 nov. 2026.
- GOOGLE. *Material Design 3*. Disponível em: https://m3.material.io. Acesso em: 4 nov. 2026.
- DENNISS, W.; BRADLEY, J. *OAuth 2.0 for Native Apps*. RFC 8252. IETF, 2017. Disponível em: https://www.rfc-editor.org/rfc/rfc8252. Acesso em: 4 nov. 2026.
- EXPO. *Prebuild*. Disponível em: https://docs.expo.dev/workflow/prebuild/. Acesso em: 4 nov. 2026.
- JETBRAINS. *Compose Multiplatform*. Disponível em: https://www.jetbrains.com/compose-multiplatform/. Acesso em: 4 nov. 2026.
- MATIAS, J. S. M. *Aula 1: Fundamentos & Panorama Mobile/Multiplataforma* e *Aula 3: Flutter a fundo*. Slides de Arquitetura de Aplicações Móveis e Multiplataforma. PUC Minas IEC, 2026.
