# ADR-0009: Provedor de identidade: Keycloak com OAuth 2.0 / OpenID Connect

- **Status:** Proposto (vira *Aceito* no PR do BFF)
- **Data:** 26/10/2026
- **Questão:** [Q13](../questoes-abertas.md#q13) · issue #13
- **Afeta no diagrama:** C4 nível 1 (Keycloak como sistema externo); C4 nível 2 (seta BFF → Keycloak para o JWKS)
- **Relacionado:** [ADR-0014](0014-modelo-de-autorizacao-rbac.md) (modelo de autorização) · [ADR-0015](0015-onde-autenticar-e-autorizar.md) (onde autenticar e autorizar)

## Contexto

- A plataforma expõe uma API REST para clientes e gestores de barbearias. Toda operação precisa saber **quem** está chamando. Este ADR decide **quem autentica o usuário e emite a credencial** que a API vai aceitar. Onde essa credencial é verificada e como as permissões são checadas ficam em [ADR-0015](0015-onde-autenticar-e-autorizar.md) e [ADR-0014](0014-modelo-de-autorizacao-rbac.md).
- Requisito não funcional: autenticação por padrão aberto (OAuth 2.0 / OpenID Connect) com tokens JWT, para que clientes web, mobile e integrações usem o mesmo mecanismo e nenhum serviço da plataforma guarde senha.
- O produto é um **marketplace multi-tenant** ([ADR-0003](0003-enquadramento-plataforma-multi-tenant.md)): o cliente tem uma conta na plataforma e agenda em qualquer barbearia; o gestor pertence a uma barbearia. A volumetria prevista é de 2 milhões de clientes e 5.000 barbearias. Isso define duas exigências para o IdP: identidade do cliente **global à plataforma** e algum vínculo do gestor com o seu tenant.
- O sistema guarda dados pessoais (nome, telefone, e-mail). A LGPD pesa a favor de um IdP maduro, com MFA, política de senha e auditoria prontos, e de controle sobre onde os dados de identidade residem.

## Opções consideradas

### A. Keycloak (escolhido)

- **Prós:** open source e projeto da CNCF (*Incubating* desde abril de 2023, doado pela Red Hat), o que dá governança neutra e comunidade ampla; implementa OAuth 2.0, OIDC e SAML, com console de administração e API REST para automação; traz MFA, federação (LDAP, redes sociais, outros IdPs) e políticas de senha para quando forem necessários; multi-tenancy dentro de um realm com a feature *Organizations*, suportada desde a versão 26.0; os dados de identidade ficam na infraestrutura da plataforma, sem transferência internacional.
- **Contras:** componente pesado (JVM) que precisa ser operado, monitorado e atualizado pela equipe; em produção exige banco próprio, TLS, hostname fixo, cluster e tuning de cache; a configuração fica num script de seed, não num export versionado do realm.

### B. Auth0 ou Amazon Cognito

- **Prós:** gerenciados, com alta disponibilidade, atualizações e certificações (SOC 2, ISO 27001) incluídas; MFA, login social e proteção contra força bruta prontos; nenhuma operação para a equipe.
- **Contras:**
  - **Lock-in na base de usuários.** O protocolo é padrão (OIDC), então trocar o IdP não muda o código das aplicações; o que prende é a **migração dos usuários**. O Cognito não exporta hashes de senha; o Auth0 só mediante solicitação ao suporte. Sair deles com 2 milhões de clientes significa forçar redefinição de senha em massa ou manter o IdP antigo vivo durante uma migração gradual.
  - **Lock-in nas extensões.** Regras de login, claims customizadas e fluxos de onboarding ficam em pontos de extensão proprietários (Auth0 *Actions*, Cognito *Lambda triggers*), reescritos do zero numa troca.
  - **Custo por usuário ativo mensal.** O custo escala com o sucesso do produto e é difícil de prever.
  - Dependência de conectividade externa e de conta no fornecedor até no ambiente de desenvolvimento.

### C. Implementação própria

Emitir e assinar tokens dentro de um serviço da plataforma (ou com uma biblioteca como Spring Authorization Server).

- **Prós:** modelo de identidade sob controle total, com o tenant nativo no esquema; sem componente externo nem JVM extra para operar; sem licença nem custo por usuário.
- **Contras:** a plataforma passa a ser responsável por hashing e política de senha, rotação de chaves, revogação de token, proteção contra força bruta e enumeração de usuários, recuperação de conta, MFA e trilha de auditoria. Cada um desses itens é um padrão com histórico de falhas em implementações caseiras e exigência de conformidade (LGPD) que o IdP pronto já cobre. É esforço de engenharia que não diferencia o produto.

### D. Outros IdPs open source (Zitadel, Authentik, Ory)

- **Prós:** mais leves que o Keycloak; o Zitadel trata organização (tenant) como conceito de primeira classe e tem multi-tenancy nativa; o Ory (Hydra + Kratos) é composável e sem interface própria, bom para quem quer controlar toda a UX.
- **Contras:** comunidades e ecossistemas menores; menos material de referência; a equipe não tem experiência com nenhum deles; a vantagem de multi-tenancy do Zitadel é coberta pelo *Organizations* do Keycloak desde a 26.0.

## Decisão

**Keycloak 26**, único IdP da plataforma, emitindo JWT assinados com RS256.

| Item | Valor |
|---|---|
| Versão | 26.6 (`start-dev` no ambiente local; porta 8080 e 9000 de gestão para `/health` e `/metrics`) |
| Realm | `barbearia`, único para a plataforma (ver abaixo) |
| Client | `bff-gateway`, confidencial, secret `bff-secret`, *direct access grants* ligado |
| Mapper | audience `bff-gateway`, para o token sair com `aud` = `bff-gateway` e só o BFF aceitá-lo |
| Roles | realm roles `cliente` e `gestor`, emitidas em `realm_access.roles` ([ADR-0014](0014-modelo-de-autorizacao-rbac.md)) |
| Usuários iniciais (ambiente local) | `cliente1`, `cliente2` (`cliente`) e `gestor1` (`gestor`), e-mail `<usuario>@barbearia.local` |
| Provisionamento | `scripts/keycloak_seed.py`, idempotente, via Admin REST API, rodado por `scripts/keycloak-seed.sh` |

### Um realm para a plataforma, não um por barbearia

Foram consideradas duas formas de modelar o tenant na identidade:

- O produto é um **marketplace** ([ADR-0003](0003-enquadramento-plataforma-multi-tenant.md)): o mesmo cliente agenda em várias barbearias e precisa de **uma** conta. Realm por barbearia obrigaria uma conta por barbearia e quebraria o modelo. Além disso, 5.000 realms está acima do que operadores relatam como limite prático de um cluster (algumas centenas, com degradação em reinício e operações administrativas; dado de comunidade, não da documentação oficial).
- **Um realm, com o tenant como vínculo do gestor.** O cliente é um usuário da plataforma, sem tenant. O gestor pertence a uma barbearia, e esse vínculo pode ser modelado de duas formas no Keycloak: um atributo `barbearia_id` no usuário, mapeado como claim; ou uma **Organization** por barbearia, com o gestor como membro, o que já emite a claim `organization` no token e permite, por barbearia, convites de membros e federação com um IdP próprio. O *Organizations* é o mecanismo oficial do Keycloak para "multi-tenancy within a realm".

**Decisão:** um realm. Na primeira versão o vínculo gestor → barbearia **não é modelado** no Keycloak, porque o isolamento entre barbearias ficou para a versão seguinte ([ADR-0014](0014-modelo-de-autorizacao-rbac.md)). Quando entrar, a opção preferida é *Organizations*, uma por barbearia; o atributo `barbearia_id` é o atalho aceitável se a única necessidade for a claim.

### Fluxo de obtenção do token

Na primeira versão não há front-end, e o token é obtido pelo *Resource Owner Password Credentials* (`grant_type=password`). Esse fluxo está depreciado no OAuth 2.1 e só é aceitável enquanto o único cliente da API for uma ferramenta de linha de comando operada pela própria equipe. Quando houver aplicação web ou mobile, cada uma ganha um client público e usa Authorization Code com PKCE.

## Consequências

- **Mais fácil:** nenhum serviço guarda senha ou implementa login; trocar a política de senha, ligar MFA ou federar com um IdP corporativo é configuração, sem código; o tenant do gestor tem um caminho de evolução (*Organizations*) sem trocar de IdP nem de realm.
- **Operação assumida:** o Keycloak é um componente de infraestrutura da plataforma, com ciclo de vida, monitoramento (`/metrics`) e atualização próprios. Em produção roda em `start` com PostgreSQL dedicado, TLS e hostname fixo, em mais de uma instância. O `start-dev` com H2 em arquivo é só para o ambiente local.
- **Risco aceito:** sem PKCE e com o *password grant*, a senha do usuário passa pelo cliente. Aceitável só enquanto o cliente for uma ferramenta operada pela equipe.
- A configuração vive num script, não num export do realm. Mudanças manuais no console se perdem ao recriar o ambiente; toda mudança de configuração deve ir para o seed.
- O Keycloak é dependência de disponibilidade para **login**: fora do ar, ninguém obtém token novo. Tokens já emitidos continuam válidos até `exp`, desde que o BFF tenha o JWKS em cache ([ADR-0015](0015-onde-autenticar-e-autorizar.md)).

## Referências

- [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749) (OAuth 2.0), [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519) (JWT), [RFC 7517](https://www.rfc-editor.org/rfc/rfc7517) (JWK), [RFC 7636](https://www.rfc-editor.org/rfc/rfc7636) (PKCE), [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html).
- [OAuth 2.1 (draft)](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-v2-1): depreciação do *password grant* e PKCE obrigatório.
- [Keycloak na CNCF](https://www.cncf.io/projects/keycloak/): nível do projeto e data de entrada.
- [Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/): realms, clients, mappers, roles e o capítulo *Managing organizations* ("enables multi-tenancy within a realm"). [Release notes](https://www.keycloak.org/docs/latest/release_notes/): *Organizations supported* em 26.0.0.
- [Configuring Keycloak for production](https://www.keycloak.org/server/configuration-production).
- Limite prático de realms por cluster (relatos de operadores, não documentação oficial): [Skycloak, How many realms can one Keycloak cluster handle](https://skycloak.io/blog/keycloak-realm-scaling-how-many-realms-per-cluster/); [Phase Two, Multi-tenancy options in Keycloak](https://phasetwo.io/blog/multi-tenancy-options-keycloak/).
- Lei nº 13.709/2018 (LGPD), capítulo V: transferência internacional de dados.
