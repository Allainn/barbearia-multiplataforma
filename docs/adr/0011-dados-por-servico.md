# ADR-0011: Dados por serviço e isolamento por barbearia

- **Status:** Aceito
- **Data:** 22/10/2026
- **Questão:** [Q12](../questoes-abertas.md#q12)
- **Afeta no diagrama:** C4 nível 2 (bancos de dados e as setas de cada serviço para eles)

## Contexto

- Eixo de dados da Aula 1: cada serviço é dono dos seus dados, sem JOIN entre serviços; a composição acontece na aplicação.
- O ambiente roda na máquina de cada integrante (Docker com 8 GB de RAM, já carregado com Keycloak, Kafka e a stack de observabilidade).
- O sistema é multi-tenant ([ADR-0003](0003-enquadramento-plataforma-multi-tenant.md)): precisamos decidir como separar os dados de cada barbearia.

## Opções consideradas (isolamento entre serviços)

### A. Uma instância PostgreSQL com um schema e um usuário por serviço

Como no PizzaExpress (`catalog_svc` só acessa o schema `catalog`).

- **Prós:** isolamento lógico real (permissão no banco impede um serviço de ler o schema do outro); uma instância só, leve para a máquina local; separar em instâncias depois é só trocar a string de conexão.
- **Contras:** a instância é um ponto único de falha e de carga no ambiente local.

### B. Uma instância por serviço

- **Prós:** isolamento físico; cada serviço pode escolher outro banco.
- **Contras:** 4 ou 5 Postgres rodando localmente; mais RAM, mais configuração.

## Opções consideradas (read model da disponibilidade)

- **PostgreSQL, schema `disponibilidade`** (proposta): sem componente novo; SQL simples por profissional e data.
- **Redis:** leitura mais rápida e TTL nativo, mas é mais um container e mais um modelo de dados para aprender.

## Opções consideradas (multi-tenancy)

- **Pool, com a coluna `barbearia_id` em todas as tabelas** (proposta): simples; o filtro por tenant fica no repositório e na checagem do token.
- **Schema por barbearia:** isolamento maior, mas inviável com 5.000 barbearias (migrações × 5.000).
- **Banco por barbearia:** só para clientes enormes; fora do nosso cenário.

## Decisão

PostgreSQL 16, uma instância, **um schema e um usuário por serviço** (`barbearia`, `agendamento`, `disponibilidade`, `notificacao`). O read model da disponibilidade fica no próprio PostgreSQL, e o multi-tenancy usa o modelo **pool**, com `barbearia_id` nas tabelas dos domínios aplicáveis.

## Consequências

- Nenhum serviço lê o schema de outro; dados de outro domínio chegam por API ou por evento.
- As consultas dos domínios multi-tenant filtram por `barbearia_id`; a validação do acesso acontece na camada responsável pela chamada, sem criar um mecanismo adicional de isolamento entre barbearias nesta entrega.
- Migrações versionadas por serviço (Flyway no Java, Alembic ou SQL puro no Python).
- O diagrama mostra **um** container PostgreSQL com os quatro schemas. O ambiente local economiza recursos, mantendo a separação lógica por permissões; em produção, cada schema pode ser movido para uma instância própria sem alterar a propriedade dos dados.

## Referências

- Aula 1 [00:36:55]: eixo de dados, banco por domínio, sem JOIN entre serviços.
- Aula 2 · P3 [00:24:41]: o pedido guarda só o ID da pizza; o dado fica no domínio dono.
- RICHARDSON, Chris. **Pattern: database per service**. Disponível em: <https://microservices.io/patterns/data/database-per-service.html>.
- Código: `pizzaexpress-ambiente/infrastructure/` (`init.sql` com schemas e usuários).
