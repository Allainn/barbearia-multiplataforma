# ADR-0014: Modelo de autorização: RBAC com duas realm roles

- **Status:** Proposto (vira *Aceito* no PR do BFF)
- **Data:** 25/10/2026
- **Questão:** [Q13](../questoes-abertas.md#q13) · issue #13
- **Afeta no diagrama:** C4 nível 2 (texto da seta pessoas → BFF: "REST com JWT; checa a role")
- **Relacionado:** [ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md) (quem emite o token) · [ADR-0015](0015-onde-autenticar-e-autorizar.md) (onde a autorização é decidida e aplicada)

## Contexto

- O [ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md) define quem autentica o usuário. Este ADR decide o **modelo de autorização**: como as permissões são expressas, ou seja, em função de quê o sistema decide que um usuário pode ou não fazer uma operação. **Onde** essa decisão é tomada e aplicada fica no [ADR-0015](0015-onde-autenticar-e-autorizar.md).
- A plataforma tem dois perfis de usuário com permissões distintas: o **cliente**, que consulta horários e reserva ou cancela os próprios agendamentos, e o **gestor**, que cadastra a barbearia, os profissionais e os serviços. Uma operação fora do perfil deve ser recusada com **403**.
- A plataforma é multi-tenant ([ADR-0003](0003-enquadramento-plataforma-multi-tenant.md)): um gestor da barbearia A não deveria alterar a B, e um cliente só deveria cancelar o próprio agendamento. Essas duas regras **não dependem só do perfil**, dependem do recurso acessado.
- A primeira versão ([roadmap](../roadmap.md)) fixou as duas roles (`cliente` e `gestor`), a tabela de rotas e deixou o isolamento entre barbearias para uma versão seguinte.

## Opções consideradas

### A. RBAC (Role-Based Access Control)

A permissão é dada à role, e o usuário recebe roles. A regra tem a forma "a operação X exige a role Y".

- **Prós:** resolve o 403 por perfil com uma comparação de string; o Keycloak emite as roles no token (`realm_access.roles`), então a decisão não precisa de nenhuma consulta; poucas roles, fácil de auditar.
- **Contras:** sozinho não expressa "só da sua barbearia" nem "só o seu agendamento"; para isso, ou se cria uma role por barbearia (explosão de roles, inviável com milhares de tenants), ou se combina com outra checagem.

### B. RBAC + atributos (tenant e dono)

Além da role, a regra olha atributos do usuário e do recurso: o token traz uma claim com a barbearia do gestor (atributo `barbearia_id` no usuário com mapper, ou a claim `organization` da feature *Organizations*, ver [ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)), comparada com o `barbearia_id` do recurso; a posse do agendamento é checada comparando o `sub` com o `cliente_id`. É RBAC para o perfil e ABAC (*Attribute-Based Access Control*) para o recurso.

- **Prós:** cobre o multi-tenant de verdade; é o desenho da primeira versão deste ADR.
- **Contras:** a comparação com o recurso só pode ser feita onde o recurso está (o serviço), o que pede autenticar a requisição também nos serviços ([ADR-0015](0015-onde-autenticar-e-autorizar.md), opção C), adiado; mais seed (atributo, mapper, um gestor por barbearia); um gestor com duas barbearias exige a claim como lista.

### C. ReBAC (Relationship-Based Access Control)

A permissão deriva de relações entre sujeitos e objetos ("gestor1 **administra** barbearia-A", "cliente1 **é dono de** agendamento-44"), no modelo Zanzibar (OpenFGA, SpiceDB). A regra "pode cancelar quem é dono" vira uma consulta ao grafo de relações.

- **Prós:** expressa tenant, dono e hierarquias (rede de barbearias, franquia) sem inflar o token; é o modelo natural para "quem pode o quê em qual objeto".
- **Contras:** exige um serviço de autorização dedicado e manter o grafo sincronizado com os dados (toda criação de barbearia ou agendamento grava uma relação); desproporcional para dois perfis e cinco rotas.

### Roles via grupo ou direto no usuário

Atribuir roles a grupos e colocar usuários nos grupos é a prática recomendada quando há muitos usuários e combinações de permissão: muda-se o grupo, não cada usuário. Com dois perfis e nenhuma combinação, o grupo acrescenta um nível de indireção sem ganho.

## Decisão

**RBAC com duas realm roles (opção A), atribuídas direto ao usuário.** As regras por recurso ficam assim: a posse do agendamento, que já existe no agendamento-service, fica; o isolamento por barbearia (B) fica para a versão seguinte.

### Roles

| Role | Quem é |
|---|---|
| `cliente` | quem reserva e cancela horário |
| `gestor` | quem cadastra a barbearia, os profissionais e os serviços |

`profissional` e `admin` (da primeira versão deste ADR) saíram: nenhuma rota do contrato depende delas. Entram quando houver agenda do profissional ou aprovação de barbearia na plataforma.

### Matriz de autorização

"Logado" quer dizer token válido, com qualquer role.

| Rota | Role | Sem token | Role errada | Regra por recurso |
|---|---|---|---|---|
| `GET /barbearias`, `GET /barbearias/{id}/profissionais`, `GET /barbearias/{id}/servicos` | logado | 401 | — | — |
| `GET /disponibilidade` | logado | 401 | — | — |
| `POST /barbearias`, `POST /barbearias/{id}/profissionais`, `POST /barbearias/{id}/servicos` | `gestor` | 401 | 403 | nenhuma (qualquer gestor altera qualquer barbearia: risco aceito) |
| `POST /agendamentos` | `cliente` | 401 | 403 | o `cliente_id` é sempre o do token, nunca vem do corpo |
| `DELETE /agendamentos/{id}` | `cliente` | 401 | 403 | só o dono cancela; para os outros, 404 |

O cancelamento de outro cliente devolve 404, não 403, para não revelar que o agendamento existe.

## Consequências

- **Mais fácil:** a regra de cada rota cabe numa linha; adicionar uma rota é declarar a role exigida; auditar as permissões é ler a matriz acima.
- **Risco aceito:** qualquer `gestor` cadastra profissional e serviço em qualquer barbearia. Em produção, isso é um vazamento entre tenants e bloqueia o lançamento para mais de uma barbearia. A evolução é a opção B: atributo `barbearia_id` no usuário do Keycloak, mapper para a claim, e o barbearia-service comparando com o `{id}` da rota.
- Se as regras crescerem para hierarquias (rede de barbearias, gestor de várias unidades, profissional que também é gestor), o modelo B satura e a opção C passa a compensar. Esse é o gatilho para revisitar este ADR.
- Uma role nova exige mudar o seed e a regra da rota; os serviços não mudam.

## Referências

- NIST, [Role-Based Access Control](https://csrc.nist.gov/projects/role-based-access-control); [NIST SP 800-162](https://csrc.nist.gov/publications/detail/sp/800-162/final) (ABAC).
- Pang et al., [Zanzibar: Google's Consistent, Global Authorization System](https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/) (ReBAC).
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html): checagem por recurso, negar por padrão, 404 × 403.
- [Keycloak: roles, composite roles e grupos](https://www.keycloak.org/docs/latest/server_admin/#assigning-permissions-using-roles-and-groups).
- [Tabela de rotas do roadmap](../roadmap.md#rotas).
