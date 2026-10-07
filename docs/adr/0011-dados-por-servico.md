# ADR-0011: Dados por serviço e isolamento por barbearia

- **Status:** Proposto
- **Data:** 07/10/2026
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

**Proposta:** PostgreSQL 16, uma instância, **um schema e um usuário por serviço** (`barbearia`, `agendamento`, `disponibilidade`, `notificacao`); read model no próprio PostgreSQL; multi-tenancy no modelo **pool** com `barbearia_id`.

## Consequências

- Nenhum serviço lê o schema de outro; dados de outro domínio chegam por API ou por evento.
- Toda consulta filtra por `barbearia_id`; o teste de 403 por tenant ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)) prova o isolamento na demo.
- Migrações versionadas por serviço (Flyway no Java, Alembic ou SQL puro no Python).
- O diagrama mostra **um** container PostgreSQL com os schemas listados; vale explicar na apresentação que, em produção, cada schema iria para uma instância própria.

## Perguntas para o grupo

- Uma instância com schemas (A) é aceitável para a apresentação, ou o grupo prefere separar ao menos o read model?
- Redis entra em algum lugar (read model, cache de catálogo) ou fica fora para não aumentar a infraestrutura?

## Referências

- Aula 1 [00:36:55]: eixo de dados, banco por domínio, sem JOIN entre serviços.
- Aula 2 · P3 [00:24:41]: o pedido guarda só o ID da pizza; o dado fica no domínio dono.
- RICHARDSON, Chris. **Pattern: database per service**. Disponível em: <https://microservices.io/patterns/data/database-per-service.html>.
- Código: `pizzaexpress-ambiente/infrastructure/` (`init.sql` com schemas e usuários).
