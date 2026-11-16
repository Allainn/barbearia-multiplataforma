# ADR-0001: Flutter para o app mobile do BarberHub

## Status

`Aceito`. Framework em 31/10; gerenciador de estado e fluxo de login em 09/11; agendamentos revistos em 13/11 (seções no fim).

**Data:** 2026-10-31 (registrado em 2026-11-04; estado e login em 2026-11-09; agendamentos em 2026-11-13)
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

## Favoritos no aparelho (`Aceito`, 09/11)

O contrato do back-end não tem favoritos. O app guarda a barbearia inteira de cada favorito em `shared_preferences`, então a aba abre sem rede e sobrevive a fechar o app; trocar de aparelho perde a lista. Evolução: uma rota de favoritos no contrato, se o produto pedir.

## Meus agendamentos: servidor como fonte da verdade, aparelho como cache dos nomes (`Aceito`, 13/11)

**Revisão:** em 09/11 o contrato não tinha rota para listar as reservas do cliente, e o app guardava no aparelho a resposta 201 de cada reserva, com os nomes que estavam na tela. A aba só mostrava o que fora reservado naquele aparelho e não ficava sabendo de um cancelamento feito por fora. Em 13/11 o `GET /agendamentos` entrou no agendamento-service e no BFF ([ADR-0016](../../docs/adr/0016-app-mobile-flutter.md)), e a aba passou a ler dele. Autor da revisão: Gabriel Santiago, no PR da feature.

**Decisão:** o `AgendamentosController` lê o `GET /agendamentos` sempre que a aba abre, ao puxar para atualizar e depois de cada cancelamento. A existência e o status de cada reserva vêm sempre do servidor: o que foi cancelado por fora aparece cancelado, e o que sumiu do servidor some da lista e do aparelho. O `shared_preferences` vira **cache dos nomes**: por id do agendamento, os nomes da barbearia, do profissional e do serviço e o preço (`ReservaLocal`), que o contrato não traz.

O problema que sobra é o dos nomes: o `GET /agendamentos` só devolve ids. Para uma reserva que não está no cache (feita em outro aparelho ou pelo `curl`), o app resolve os nomes pelo catálogo que já existe (`CatalogoNomes`): um `GET /barbearias` e, para cada barbearia diferente, `/profissionais` e `/servicos`. São chamadas por barbearia, não por agendamento.

| Opção para os nomes | A favor | Contra |
|---|---|---|
| **Cache no aparelho + catálogo para o que faltar** (escolhida) | Nenhuma mudança no contrato; a reserva feita aqui mostra os nomes e o preço da hora da reserva, sem nenhuma chamada a mais; o que veio de outro aparelho custa três chamadas por barbearia, uma vez (depois fica no cache) | O preço de uma reserva de outro aparelho é o do catálogo de hoje, não o da hora da reserva; um profissional ou serviço apagado do catálogo vira texto neutro ("Barbearia não identificada", "Detalhes indisponíveis no momento") |
| Nomes no `GET /agendamentos` (o agendamento-service guarda ou o BFF agrega) | Uma chamada só; o preço da hora da reserva em qualquer aparelho | Muda o contrato de novo, em dois serviços: o agendamento-service teria que guardar nomes de outro serviço, ou o BFF passaria a agregar (o BFF por canal que o ADR-0016 deixou como evolução) |
| Catálogo para tudo, sem cache | Uma regra só | Chamadas a cada abertura da aba; sem rede, a aba não mostra nada |

Estados: carregando, vazio e erro como nas outras abas, com puxar para atualizar. **Sem rede ou com o serviço fora (503)**, a aba mostra o que está no cache com um aviso de que pode estar desatualizado, em vez de um erro sem nada. Sem cache, ela mostra o erro com "Tentar de novo". Um 401 segue o fluxo da sessão (o `BffClient` encerra a sessão e volta ao login). Se o catálogo falhar, a reserva aparece com o texto neutro, e a próxima carga tenta os nomes de novo.

Mitigações que continuam: o cache é separado por conta (o `cliente_id` de cada reserva), então duas contas no mesmo aparelho não veem as reservas uma da outra; um `DELETE` que volta 404 (reserva que não existe mais no servidor) conta como cancelado, e a releitura tira a reserva da lista.

## Referências

- FLUTTER. *Flutter documentation*. Google, 2026. Disponível em: https://docs.flutter.dev. Acesso em: 4 nov. 2026.
- GOOGLE. *Material Design 3*. Disponível em: https://m3.material.io. Acesso em: 4 nov. 2026.
- DENNISS, W.; BRADLEY, J. *OAuth 2.0 for Native Apps*. RFC 8252. IETF, 2017. Disponível em: https://www.rfc-editor.org/rfc/rfc8252. Acesso em: 4 nov. 2026.
- EXPO. *Prebuild*. Disponível em: https://docs.expo.dev/workflow/prebuild/. Acesso em: 4 nov. 2026.
- JETBRAINS. *Compose Multiplatform*. Disponível em: https://www.jetbrains.com/compose-multiplatform/. Acesso em: 4 nov. 2026.
- MATIAS, J. S. M. *Aula 1: Fundamentos & Panorama Mobile/Multiplataforma* e *Aula 3: Flutter a fundo*. Slides de Arquitetura de Aplicações Móveis e Multiplataforma. PUC Minas IEC, 2026.
