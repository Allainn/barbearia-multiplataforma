# contracts

O contrato entre os serviços está em [docs/tarefas.md](../docs/tarefas.md#contrato): containers, portas, rotas, eventos do Kafka, banco, Keycloak e dados fixos. Ele ficou num documento só, que cada integrante entregou à própria IA ([ADR-0002](../docs/adr/0002-monorepo-e-estrutura.md)).

Esta pasta foi pensada para os contratos em formato de máquina (JSON Schema ou AsyncAPI para os eventos, OpenAPI para as rotas), que ficaram como evolução ([ADR-0006](../docs/adr/0006-comunicacao-sincrona-e-kafka.md)). As rotas dos serviços Python estão documentadas no Swagger que o FastAPI gera em `/docs`.
