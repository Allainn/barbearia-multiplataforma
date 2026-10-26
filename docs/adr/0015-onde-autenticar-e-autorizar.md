# ADR-0015: Onde autenticar e autorizar: ponto de aplicação e ponto de decisão

- **Status:** Aceito
- **Data:** 26/10/2026
- **Questão:** [Q13](../questoes-abertas.md#q13) · issue #13
- **Afeta no diagrama:** C4 nível 2 (seta pessoas → BFF: "REST com JWT"; seta BFF → Keycloak: "JWKS"; setas BFF → serviços: "REST com `X-User-ID`")
- **Relacionado:** [ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md) (quem emite o token) · [ADR-0014](0014-modelo-de-autorizacao-rbac.md) (modelo de autorização)

## Contexto

- O Keycloak autentica o usuário e emite um JWT ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)). As permissões são expressas por roles ([ADR-0014](0014-modelo-de-autorizacao-rbac.md)). Falta decidir **onde** isso acontece dentro da plataforma, e são duas perguntas distintas:
  1. **Onde a requisição é autenticada:** qual componente verifica o token (assinatura, `exp`, `iss`, `aud`) e estabelece quem está chamando. Só na borda (BFF), em cada serviço, ou nos dois.
  2. **Onde a autorização é decidida e aplicada:** quem avalia "este usuário pode fazer isto neste recurso" (o *Policy Decision Point*, PDP) e quem bloqueia a requisição (o *Policy Enforcement Point*, PEP). O PDP pode ser o código da própria aplicação, o Keycloak (Authorization Services) ou um serviço dedicado.
- A fronteira de confiança define o risco: tudo o que fica depois do ponto de autenticação confia num header, não num token. Autenticar só na borda é adequado a sistemas de menor criticidade e rede interna fechada; em sistemas críticos, cada serviço autentica a requisição (defesa em profundidade).
- Há duas naturezas de regra ([ADR-0014](0014-modelo-de-autorizacao-rbac.md)): **por papel** (precisa só do token) e **por recurso** (precisa do dado: quem é o dono do agendamento, de quem é a barbearia). A segunda só pode ser decidida onde o dado está, ou por um PDP que tenha cópia dele.
- A primeira versão ([roadmap](../roadmap.md)) tem 5 rotas, 2 roles e sem isolamento entre barbearias. Linguagens: Java no BFF e no agendamento, Python nos outros ([ADR-0005](0005-linguagens-por-servico.md)).

## Opções consideradas (onde autenticar a requisição)

### A. Só na borda (BFF)

O BFF verifica o token e repassa a identidade do chamador aos serviços num header (`X-User-ID` = claim `sub`). Os serviços confiam no header.

- **Prós:** mais simples; um único ponto de configuração e de cache do JWKS; 401 antes de qualquer chamada interna; código de referência pronto.
- **Contras:** quem alcançar a rede interna chama qualquer serviço sem token e forja o `X-User-ID`; as regras por recurso, que ficam nos serviços, dependem de um header não verificável.

### B. Em cada serviço

Cada serviço verifica o token; o BFF só roteia (ou também verifica, como atalho).

- **Prós:** defesa em profundidade; cada serviço decide com uma identidade que ele mesmo verificou.
- **Contras:** biblioteca de verificação em Java (Spring Security Resource Server) e em Python (PyJWT + JWKS); cada serviço depende do Keycloak para subir; o token precisa ser repassado em todas as chamadas internas, incluindo as assíncronas se forem autorizadas.

### C. Híbrido: a borda autentica tudo; os serviços que escrevem reautenticam

O BFF corta cedo as requisições inválidas; agendamento-service e barbearia-service, que alteram dados e aplicam regra por recurso, verificam o token repassado. Disponibilidade e notificação confiam no header.

- **Prós:** o custo da defesa em profundidade só onde há escrita e regra por recurso; os serviços de leitura ficam simples.
- **Contras:** duas lógicas de verificação para manter coerentes; o BFF precisa repassar o `Authorization` original.

## Opções consideradas (quem decide a autorização)

### 1. PDP embutido na aplicação, com as claims do token

A aplicação lê `realm_access.roles` (e, no futuro, `barbearia_id`) do token e decide localmente: regra por rota na configuração de segurança do BFF, `cliente_id == X-User-ID` no agendamento-service. Keycloak só emite; não é consultado por requisição.

- **Prós:** zero latência adicional e nenhuma dependência de rede na decisão; funciona igual em Java e Python; a regra fica ao lado da rota, fácil de ler e testar.
- **Contras:** as regras ficam espalhadas pelo código de cada serviço; mudar uma política é deploy; com muitas regras por recurso vira duplicação.

### 2. PDP no Keycloak (Authorization Services / UMA 2.0)

Recursos, escopos e políticas (por role, usuário, grupo, horário, script) são cadastrados no Keycloak. A aplicação pede ao Keycloak uma decisão (ou um RPT, token com as permissões) e aplica. O enforcement fica num adaptador (`keycloak-policy-enforcer`, Java).

- **Prós:** políticas centralizadas no mesmo lugar das identidades, editáveis no console sem deploy; modelo de recursos e escopos padronizado (UMA).
- **Contras:** uma chamada ao Keycloak por requisição (ou cache do RPT, que pode ficar obsoleto); o Keycloak vira dependência de disponibilidade e de latência de **toda** requisição, não só do login; o único *policy enforcer* oficial de servidor é o Java (`org.keycloak:keycloak-policy-enforcer`), biblioteca específica do Keycloak que não se integra ao Spring Security (o próprio projeto registra que Spring Security, Quarkus OIDC e Elytron "have no support for Keycloak Authorization Services"); o enforcer de Node.js vive no adaptador `keycloak-connect`, depreciado pelo projeto em 2022; para Python não há enforcer, e os serviços teriam de implementar o PEP chamando o token endpoint com o *UMA grant* (`response_mode=decision`) a cada requisição; o Keycloak não conhece os recursos do domínio (cada agendamento teria de ser registrado nele como recurso para decidir "é dono"), o que acopla o IdP ao modelo de dados; curva de aprendizado alta para a equipe.

### 3. PDP dedicado (motor de políticas ou serviço de autorização)

Um componente separado responde "permitido/negado": motor de políticas por atributos (OPA com Rego, Cerbos) ou serviço de relações no modelo Zanzibar (OpenFGA, SpiceDB). Pode rodar como sidecar (OPA) ou serviço central (OpenFGA).

- **Prós:** políticas versionadas e testadas fora do código da aplicação; um só lugar para auditar; cobre regra por recurso e hierarquias (rede de barbearias) sem inflar o token; agnóstico de linguagem (gRPC/HTTP).
- **Contras:** mais um componente para operar e observar; latência de uma chamada por decisão (sidecar mitiga); para regras por recurso, o PDP precisa dos dados (OPA: a aplicação passa o recurso no input; OpenFGA: o grafo de relações precisa ser alimentado a cada escrita no domínio); desproporcional para duas roles e cinco rotas.

## Decisão

**Autenticação só na borda (A) e autorização decidida pela própria aplicação, com as claims do token (1).** O BFF é o único ponto que autentica a requisição. A autorização é aplicada em dois pontos, conforme a natureza da regra: a regra **por papel** no BFF, antes de encaminhar; a regra **por recurso** no serviço que guarda o recurso, com a identidade que o BFF repassou. Nenhum dos dois consulta o Keycloak ou outro componente para decidir.

### Autenticação: como o BFF autentica a requisição

1. Lê o `Authorization: Bearer <token>`. Ausente → 401.
2. Busca a chave pública no JWKS do realm (`$KEYCLOAK_URL/protocol/openid-connect/certs`) pelo `kid`, com cache, e confere a assinatura RS256.
3. Confere `exp`, `iss` (= `KEYCLOAK_URL`) e `aud` (contém `KEYCLOAK_CLIENT_ID`). Qualquer falha → 401 com `WWW-Authenticate: Bearer`.
4. Constrói a identidade do chamador a partir das claims: `sub` e `realm_access.roles`. A partir daqui a requisição está autenticada.
5. Ao encaminhar, repassa o `sub` no header `X-User-ID` e **não repassa** o `Authorization`. Os serviços confiam no header e não verificam nada.

Modo bypass: se `KEYCLOAK_URL` estiver vazio, o BFF não verifica e usa um usuário fixo com as roles `cliente` e `gestor`. Serve só para desenvolvimento local; o compose sempre define `KEYCLOAK_URL`.

### Autorização: onde é decidida e aplicada

O PDP é o código da aplicação; o PEP é o ponto do fluxo onde a decisão bloqueia a requisição. A entrada da decisão são só as claims do token (no BFF) ou o `X-User-ID` e o dado do recurso (no serviço). Não há chamada de rede para decidir.

- **Regra por papel, no BFF.** A matriz do [ADR-0014](0014-modelo-de-autorizacao-rbac.md) é declarada num só lugar, na configuração do Spring Security (`RegrasDeAutorizacao`: método + caminho → `authenticated()` ou `hasRole(...)`), e avaliada pelo filtro de segurança **antes** de qualquer controller. A role vem de `realm_access.roles`, já no token. Falha → 403, sem tocar o serviço. Negar por padrão é estrutural: a matriz termina em `anyRequest().denyAll()`, então uma rota nova que não esteja listada é recusada mesmo com token válido; adicionar uma rota ao BFF é acrescentar a linha dela na matriz. Os controllers só encaminham.
- **Regra por recurso, no serviço dono do dado.** O BFF não conhece os recursos, então não consegue decidir "este agendamento é deste usuário". Essa decisão fica no caso de uso do serviço, comparando o `X-User-ID` com o `cliente_id` gravado. Resposta 404 para não revelar a existência do recurso. É a única regra por recurso da primeira versão; a de tenant (gestor × barbearia) não existe ainda.
- **O que o BFF faz com a identidade além de decidir:** no `POST /agendamentos`, o `cliente_id` gravado é sempre o `X-User-ID`, nunca o do corpo. Isso não é uma checagem, é a eliminação de uma: o cliente não escolhe em nome de quem reserva.

### Onde cada checagem acontece

| Checagem | Natureza | PDP / PEP | Resposta |
|---|---|---|---|
| O token existe, a assinatura bate com o JWKS, `exp`, `iss` e `aud` estão certos | autenticação da requisição | BFF, Spring Security OAuth2 Resource Server (`KeycloakSecurityConfig`) | 401 com `WWW-Authenticate: Bearer` |
| O usuário tem a role da rota | autorização por papel | BFF, matriz declarativa em `RegrasDeAutorizacao`, no filtro de segurança | 403 |
| O agendamento é do usuário | autorização por recurso (dono) | agendamento-service, no caso de uso de cancelar, com `X-User-ID` | 404 |
| A barbearia é do gestor | autorização por recurso (tenant) | **não implementado** | — |

## Consequências

- **Mais fácil:** um único lugar com a configuração de segurança; os serviços não dependem do Keycloak para subir; a decisão de autorização não adiciona latência nem dependência de rede.
- **Risco aceito (o principal deste ADR):** a fronteira de confiança é a rede interna. Quem alcançar um serviço sem passar pelo BFF reserva ou cancela em nome de qualquer cliente, só mandando outro `X-User-ID`. Por isso os serviços de domínio **não publicam porta no host**: só o BFF é alcançável de fora do Compose, e a rede `observability` é a fronteira. Isso reduz a superfície, mas não resolve o problema: qualquer processo dentro da rede (outro container, um atacante que comprometeu um serviço) continua podendo forjar o header. O caminho correto é a opção C (ou B), ou mTLS entre o BFF e os serviços.
- **Gatilhos para rever a decisão:**
  - Isolamento por barbearia entra ([ADR-0014](0014-modelo-de-autorizacao-rbac.md), opção B) → a regra por recurso no barbearia-service precisa de identidade verificada → opção **C** deste ADR, com o BFF repassando o `Authorization`.
  - Regras passam a variar por plano, por barbearia ou por hierarquia → o PDP embutido vira duplicação → opção **3** (OpenFGA para relações; OPA se as regras forem por atributo). A opção 2 (Keycloak) continua descartada mesmo nesse cenário, pelo acoplamento do IdP aos recursos do domínio e pela falta de *policy enforcer* para Python.
- O BFF guarda o JWKS em cache: se o Keycloak cair, tokens já emitidos continuam aceitos até `exp`; só login novo falha.
- **O `iss` tem de ser um só.** Sem hostname fixo, o Keycloak monta o `iss` com a URL pela qual foi chamado: um token obtido por `http://localhost:8080` sairia com esse `iss`, e o BFF, que o conhece como `http://keycloak:8080`, o recusaria com 401 (`The iss claim is not valid`). Aceitar vários issuers no BFF afrouxaria a verificação. A solução é no Keycloak: `KC_HOSTNAME=http://keycloak:8080` fixa o `iss` venha o login de onde vier, e `KC_HOSTNAME_ADMIN=http://localhost:8080` mantém o console acessível do host. É a mesma exigência de hostname fixo que a produção tem ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)).
- A verificação da assinatura é do token inteiro, bit a bit. Para demonstrar um token adulterado, altera-se um caractere do **meio** da assinatura ou do payload; o último caractere do base64url carrega só 2 bits úteis e, dependendo do valor, a troca não muda a assinatura decodificada.
- Se a opção C entrar, um ADR novo substitui este. O [ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md) e o [ADR-0014](0014-modelo-de-autorizacao-rbac.md) não mudam por isso.

## Referências

- [RFC 7519 §7.2](https://www.rfc-editor.org/rfc/rfc7519#section-7.2) (validação do JWT), [RFC 6750](https://www.rfc-editor.org/rfc/rfc6750) (Bearer Token, `WWW-Authenticate`), [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725) (JWT Best Current Practices: conferir `aud`, algoritmo fixo).
- [OAuth 2.0 Security Best Current Practice](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics).
- [NIST SP 800-162 §2](https://csrc.nist.gov/publications/detail/sp/800-162/final): PEP, PDP e PIP. [XACML 3.0](https://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html): arquitetura de referência.
- [Keycloak Authorization Services Guide](https://www.keycloak.org/docs/latest/authorization_services/) (capítulo *Policy enforcers*: enforcers embutidos só para Java e JavaScript), [Keycloak Policy Enforcer](https://www.keycloak.org/securing-apps/policy-enforcer) (Java) e [UMA 2.0](https://docs.kantarainitiative.org/uma/wg/rec-oauth-uma-grant-2.0.html).
- Keycloak, [Deprecation of Keycloak adapters](https://www.keycloak.org/2022/02/adapter-deprecation) (fev/2022) e [Update on deprecation](https://www.keycloak.org/2023/03/adapter-deprecation-update) (mar/2023): adaptadores Java e Node.js depreciados; frameworks substitutos sem suporte a Authorization Services.
- [Open Policy Agent](https://www.openpolicyagent.org/docs/latest/), [OpenFGA](https://openfga.dev/docs), [Cerbos](https://docs.cerbos.dev/).
- NIST SP 800-207, [Zero Trust Architecture](https://csrc.nist.gov/publications/detail/sp/800-207/final): por que não confiar na rede interna.
- [Spring Security: OAuth 2.0 Resource Server (JWT)](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html) e [Authorize HttpServletRequests](https://docs.spring.io/spring-security/reference/servlet/authorization/authorize-http-requests.html).
- Código: `services/bff-gateway/src/main/java/com/barbearia/bff/infrastructure/auth/` (`KeycloakSecurityConfig`, `RegrasDeAutorizacao`, `RealmRolesConverter`, `RespostasDeSeguranca`, `BypassSecurityConfig`); `services/bff-gateway/.../infrastructure/clients/ServicoClient.java` (`X-User-ID`, sem `Authorization`); `services/agendamento-service/.../infrastructure/http/AgendamentoController.java` (dono no cancelamento).
