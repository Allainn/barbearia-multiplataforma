# ADR-0009: Segurança: Keycloak, OAuth2/OIDC e onde validar o JWT

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q13](../questoes-abertas.md#q13)
- **Afeta no diagrama:** C4 nível 1 (Keycloak como sistema externo); C4 nível 2 (setas de autenticação e validação)

## Contexto

- O trabalho exige um IdP com OAuth2/OIDC e JWT, e a demonstração de **401** (token ausente ou inválido) e **403** (role insuficiente), com o modelo justificado: validação só no BFF ou em cada serviço.
- O sistema é **multi-tenant** ([ADR-0003](0003-enquadramento-plataforma-multi-tenant.md)): o gestor da barbearia A não pode alterar a barbearia B, mesmo tendo a role `gestor`. Há dados pessoais de clientes (nome, telefone), o que pesa a favor de mais rigor (LGPD).
- O professor: segurança só no BFF serve para sistemas simples; em sistemas críticos, cada serviço valida o token (Aula 1 [01:16:31]; Aula 2 · P1 [00:35:38]).

## Opções consideradas (IdP)

**Keycloak** (proposta): open source, roda local, é o das aulas, e o seed do PizzaExpress (realm, clients, roles, usuários) é reaproveitável. Auth0 ou Cognito dependem de nuvem e conta; IdP próprio é solução caseira, o que o professor desaconselha (Aula 2 · P3 [00:29:03]).

## Opções consideradas (onde validar)

### A. Só no BFF (modelo 1 da Aula 2)

O BFF valida assinatura (JWKS), `exp`, `iss`, `aud` e roles; repassa `X-User-ID` (claim `sub`) para os serviços, que confiam nele.

- **Prós:** mais simples; um único ponto de configuração; é o exemplo pronto do PizzaExpress.
- **Contras:** quem chegar à rede interna chama qualquer serviço sem token; a checagem de tenant fica concentrada no BFF, longe do domínio.

### B. Em cada serviço (modelo 2 da Aula 2)

- **Prós:** defesa em profundidade; cada serviço aplica a própria regra de autorização, incluindo o tenant.
- **Contras:** biblioteca de validação em Java e Python; mais configuração.

### C. Híbrido: o BFF valida tudo e os serviços que escrevem também validam o JWT repassado

- **Prós:** o BFF corta cedo as requisições inválidas (401/403 sem tocar nos serviços); agendamento e barbearia-service, que alteram dados, revalidam o token e checam o tenant; disponibilidade e notificação ficam mais simples.
- **Contras:** duas lógicas de validação para manter coerentes.

## Decisão

**Proposta:** Keycloak 26 + opção **C**.

- **Realm** único da plataforma. **Clients:** `bff-gateway` (audience dos tokens), `app-cliente` e `painel-barbearia` (públicos, Authorization Code + **PKCE**). Na demo com curl, usamos *direct access grant* para obter o token, como no PizzaExpress.
- **Roles via grupos** (boa prática da Aula 2): `cliente`, `profissional`, `gestor`, `admin`.
- **Tenant:** atributo de usuário `barbearia_id`, mapeado como claim no token para profissionais e gestores.
- **Validação:** assinatura RS256 via JWKS, `exp`, `iss`, `aud`, roles; nos serviços que escrevem, também `barbearia_id` do token = `barbearia_id` do recurso.

### Matriz de autorização (rascunho)

| Operação | cliente | profissional | gestor | admin |
|---|---|---|---|---|
| Consultar barbearias, serviços e horários livres | ✅ | ✅ | ✅ | ✅ |
| Reservar e cancelar o próprio agendamento | ✅ | — | — | — |
| Ver a agenda do dia | — | ✅ (só a própria) | ✅ (só da sua barbearia) | ✅ |
| Cadastrar serviços, profissionais e expediente | ❌ 403 | ❌ 403 | ✅ (só da sua barbearia; outra → 403) | ✅ |
| Aprovar barbearia na plataforma | ❌ 403 | ❌ 403 | ❌ 403 | ✅ |

### Cenários da demo

1. Sem token → **401** no BFF.
2. Token expirado ou adulterado → **401**.
3. Cliente tenta cadastrar serviço → **403** (role).
4. Gestor da barbearia A tenta alterar a barbearia B → **403** (tenant).
5. Chamada direta ao agendamento-service sem passar pelo BFF e sem token → **401** (prova a defesa em profundidade).

## Consequências

- O seed do Keycloak precisa criar o realm, os clients, os grupos com roles, o mapper de `barbearia_id` e usuários de teste (um por papel, dois gestores de barbearias diferentes).
- Java: Spring Security Resource Server. Python: o validador JWKS do `bff-gateway` do PizzaExpress vira uma biblioteca reaproveitada.
- Se o tempo apertar, recuamos para A e registramos a troca num ADR novo.

## Perguntas para o grupo

- Híbrido (C) ou só BFF (A)? A diferença na demo é o cenário 5.
- A consulta de horários livres precisa de login ou pode ser pública (na vida real, seria)?
- PKCE entra na demo (é desejável) ou fica só citado?

## Referências

- Aula 2 · P1 [00:24:02]: modelo 1, segurança no BFF, 401 e 403.
- Aula 2 · P1 [00:35:38]: modelo 2, cada serviço valida; recomendado em sistemas críticos.
- Aula 2 · P1 [00:39:22]–[00:47:04]: `X-User-ID`, claim `sub`.
- Aula 2 · P1 [00:51:38]: clients, roles em grupos.
- Aula 3 · P3 [00:05:37]–[00:19:30]: PKCE na prática.
- Código: `pizzaexpress-ambiente/services/bff-gateway/src/bff/infrastructure/auth/` e `scripts/keycloak-seed.sh`.
