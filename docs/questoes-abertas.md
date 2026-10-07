# Questões em aberto

As questões seguem a ordem em que o diagrama C4 é construído: primeiro o que o sistema é, depois o nível 1 (contexto), o nível 2 (containers) e o nível 3 (componentes). Respondê-las em ordem desenha o diagrama aos poucos; o esboço no Miro marca com uma etiqueta amarela onde cada questão pesa.

Cada questão tem uma **issue** com a label `questao`, onde acontece a discussão. Quando o grupo decide, o ADR ligado vai para *Aceito* (por PR) e a issue é fechada. Fluxo completo em [CONTRIBUTING.md](../CONTRIBUTING.md).

> A "proposta inicial" de cada questão é só um ponto de partida para a conversa, escrito junto com os ADRs *Propostos*. Nada aqui está decidido.

## Índice

| # | Questão | Afeta no diagrama | ADR | Prazo | Issue |
|---|---|---|---|---|---|
| [Q01](#q01) | Como enquadrar o sistema para ter escala? | C4 nível 1: nome e descrição do sistema; slide de abertura (volumetria) | [ADR-0003](adr/0003-enquadramento-plataforma-multi-tenant.md) | 10/10 | [#1](https://github.com/Allainn/barbearia-multiplataforma/issues/1) |
| [Q02](#q02) | Qual o nome do produto? | C4 nível 1 (caixa central) e nível 2 (fronteira do sistema); slides; nome do repositório | — | 10/10 | [#2](https://github.com/Allainn/barbearia-multiplataforma/issues/2) |
| [Q03](#q03) | Qual o escopo funcional mínimo da demo? | C4 nível 1 (o que o sistema faz) e nível 2 (quais containers precisam existir) | [ADR-0003](adr/0003-enquadramento-plataforma-multi-tenant.md), [ADR-0004](adr/0004-decomposicao-em-servicos.md) | 10/10 | [#3](https://github.com/Allainn/barbearia-multiplataforma/issues/3) |
| [Q04](#q04) | Quem são os atores (pessoas) do C4 nível 1? | C4 nível 1: as pessoas e as setas "usa" | [ADR-0003](adr/0003-enquadramento-plataforma-multi-tenant.md) | 10/10 | [#4](https://github.com/Allainn/barbearia-multiplataforma/issues/4) |
| [Q05](#q05) | Quais sistemas externos aparecem no C4 nível 1? | C4 nível 1: sistemas externos (cinza); C4 nível 2: setas que saem do sistema | [ADR-0004](adr/0004-decomposicao-em-servicos.md), [ADR-0009](adr/0009-seguranca-keycloak-e-validacao-jwt.md) | 10/10 | [#5](https://github.com/Allainn/barbearia-multiplataforma/issues/5) |
| [Q06](#q06) | Os front-ends aparecem no diagrama? | C4 nível 2: containers de front-end (app do cliente, painel da barbearia) | [ADR-0004](adr/0004-decomposicao-em-servicos.md) | 10/10 | [#6](https://github.com/Allainn/barbearia-multiplataforma/issues/6) |
| [Q07](#q07) | Quais containers (serviços) o sistema terá? | C4 nível 2 inteiro | [ADR-0004](adr/0004-decomposicao-em-servicos.md) | 12/10 | [#7](https://github.com/Allainn/barbearia-multiplataforma/issues/7) |
| [Q08](#q08) | Quais linguagens, e em quais serviços? | C4 nível 2: a tecnologia anotada em cada container | [ADR-0005](adr/0005-linguagens-por-servico.md) | 10/10 | [#8](https://github.com/Allainn/barbearia-multiplataforma/issues/8) |
| [Q09](#q09) | Um BFF para todos os canais ou um por canal? Em qual tecnologia? | C4 nível 2: container(s) de entrada | [ADR-0004](adr/0004-decomposicao-em-servicos.md), [ADR-0005](adr/0005-linguagens-por-servico.md) | 12/10 | [#9](https://github.com/Allainn/barbearia-multiplataforma/issues/9) |
| [Q10](#q10) | Qual broker de mensagens? Quais tópicos e chaves de partição? | C4 nível 2: container do broker e setas de publicação/consumo | [ADR-0006](adr/0006-comunicacao-sincrona-e-kafka.md) | 12/10 | [#10](https://github.com/Allainn/barbearia-multiplataforma/issues/10) |
| [Q11](#q11) | O que é síncrono e o que é assíncrono? (as setas do nível 2) | C4 nível 2: protocolo e descrição de cada seta | [ADR-0006](adr/0006-comunicacao-sincrona-e-kafka.md) | 12/10 | [#11](https://github.com/Allainn/barbearia-multiplataforma/issues/11) |
| [Q12](#q12) | Como organizar os bancos de dados? | C4 nível 2: containers de banco e setas de cada serviço para eles | [ADR-0011](adr/0011-dados-por-servico.md) | 12/10 | [#12](https://github.com/Allainn/barbearia-multiplataforma/issues/12) |
| [Q13](#q13) | Onde validar o JWT? Como isolar uma barbearia da outra? | C4 nível 1 (Keycloak); C4 nível 2 (setas de autenticação e validação) | [ADR-0009](adr/0009-seguranca-keycloak-e-validacao-jwt.md) | 12/10 | [#13](https://github.com/Allainn/barbearia-multiplataforma/issues/13) |
| [Q14](#q14) | Como impedir dois clientes no mesmo horário? (lock) | C4 nível 2 (agendamento-service → PostgreSQL); C4 nível 3 do agendamento | [ADR-0007](adr/0007-concorrencia-na-reserva-de-horario.md) | 12/10 | [#14](https://github.com/Allainn/barbearia-multiplataforma/issues/14) |
| [Q15](#q15) | CQRS lite ou completo na consulta de disponibilidade? | C4 nível 2: disponibilidade-service, seu banco e as setas vindas do Kafka | [ADR-0008](adr/0008-cqrs-na-consulta-de-disponibilidade.md) | 12/10 | [#15](https://github.com/Allainn/barbearia-multiplataforma/issues/15) |
| [Q16](#q16) | Outbox Pattern entra? Polling ou Debezium? | C4 nível 2 (seta agendamento → Kafka); C4 nível 3 do agendamento | [ADR-0012](adr/0012-garantia-de-publicacao-outbox.md) | 12/10 | [#16](https://github.com/Allainn/barbearia-multiplataforma/issues/16) |
| [Q17](#q17) | Lembretes (véspera e 1 h antes) entram no escopo? | C4 nível 2: notificacao-service (e um agendador de tarefas, se entrar) | [ADR-0004](adr/0004-decomposicao-em-servicos.md) | 12/10 | [#17](https://github.com/Allainn/barbearia-multiplataforma/issues/17) |
| [Q18](#q18) | Clean ou Hexagonal dentro dos serviços? Qual serviço ganha o C4 nível 3? | C4 nível 3 | [ADR-0010](adr/0010-arquitetura-interna-dos-servicos.md) | 14/10 | [#18](https://github.com/Allainn/barbearia-multiplataforma/issues/18) |
| [Q19](#q19) | Qual pipeline de CI/CD e onde roda o deploy? | Diagrama de implantação (se fizermos) e a parte de CI/CD da demo | [ADR-0013](adr/0013-entrega-continua-e-observabilidade.md) | 14/10 | [#19](https://github.com/Allainn/barbearia-multiplataforma/issues/19) |
| [Q20](#q20) | O que mostrar de observabilidade? | C4 nível 2 (stack de observabilidade, se for desenhada); demo | [ADR-0013](adr/0013-entrega-continua-e-observabilidade.md) | 14/10 | [#20](https://github.com/Allainn/barbearia-multiplataforma/issues/20) |
| [Q21](#q21) | Qual o roteiro da demo e quem apresenta cada parte? | Apresentação | — | 24/10 | [#21](https://github.com/Allainn/barbearia-multiplataforma/issues/21) |
| [Q22](#q22) | Qual o papel de cada integrante? | Dono de cada container do C4 nível 2 | — | 10/10 | [#22](https://github.com/Allainn/barbearia-multiplataforma/issues/22) |
| [Q23](#q23) | Convenções: quórum de ADR, idioma do código, commits | Nomes de containers, tópicos e endpoints no diagrama | [ADR-0001](adr/0001-registrar-decisoes-com-adr.md), [ADR-0002](adr/0002-monorepo-e-estrutura.md) | 10/10 | [#23](https://github.com/Allainn/barbearia-multiplataforma/issues/23) |
| [Q24](#q24) | Onde fica o diagrama oficial? | Todos os diagramas | — | 14/10 | [#24](https://github.com/Allainn/barbearia-multiplataforma/issues/24) |

## Enquadramento (antes do diagrama)

Definem o que o sistema é. Sem isso não dá para desenhar a caixa central do C4 nível 1.

<a id="q01"></a>

### Q01 · Como enquadrar o sistema para ter escala?

- **Afeta no diagrama:** C4 nível 1: nome e descrição do sistema; slide de abertura (volumetria)
- **ADR:** [ADR-0003: Enquadrar o sistema como plataforma multi-tenant de agendamento](adr/0003-enquadramento-plataforma-multi-tenant.md)
- **Prazo:** 10/10 · **Issue:** [#1](https://github.com/Allainn/barbearia-multiplataforma/issues/1)

**Contexto.** O professor descarta sistemas pequenos ("padaria de bairro"). A agenda de uma única barbearia não tem volume que justifique Kafka nem CQRS.

**Opções na mesa**

1. SaaS multi-tenant: muitas barbearias usam a mesma plataforma para gerir a agenda
2. Marketplace multi-tenant: o SaaS + o cliente busca horários em qualquer barbearia da plataforma
3. Outro recorte (trazer a proposta)

**Proposta inicial (para discussão):** Marketplace multi-tenant, com a volumetria do ADR-0003 (5.000 barbearias, 150 mil agendamentos/dia, 7,5 milhões de consultas de horário/dia).

<a id="q02"></a>

### Q02 · Qual o nome do produto?

- **Afeta no diagrama:** C4 nível 1 (caixa central) e nível 2 (fronteira do sistema); slides; nome do repositório
- **Prazo:** 10/10 · **Issue:** [#2](https://github.com/Allainn/barbearia-multiplataforma/issues/2)

**Contexto.** O nome aparece em todos os diagramas e slides. O repositório usa o nome provisório barbearia-multiplataforma, que dá para renomear no GitHub sem perder nada.

**Opções na mesa**

1. NaRégua
2. BarberHub
3. Cadeira Livre
4. Outra sugestão (comente)

**Proposta inicial (para discussão):** Votação rápida nos comentários (um 👍 por sugestão).

<a id="q03"></a>

### Q03 · Qual o escopo funcional mínimo da demo?

- **Afeta no diagrama:** C4 nível 1 (o que o sistema faz) e nível 2 (quais containers precisam existir)
- **ADR:** [ADR-0003: Enquadrar o sistema como plataforma multi-tenant de agendamento](adr/0003-enquadramento-plataforma-multi-tenant.md) · [ADR-0004: Decomposição em serviços (containers do C4 nível 2)](adr/0004-decomposicao-em-servicos.md)
- **Prazo:** 10/10 · **Issue:** [#3](https://github.com/Allainn/barbearia-multiplataforma/issues/3)

**Contexto.** Tudo o que for desenhado precisa ser implementado, e regra de negócio não vale nota. O escopo tem que ser o mínimo que exercita as integrações.

**Opções na mesa**

1. Gestor cadastra barbearia, profissionais, serviços e expediente
2. Cliente consulta horários livres
3. Cliente agenda (com conflito 409 na disputa)
4. Cliente cancela
5. Confirmação e cancelamento enviados por mensagem (provedor simulado)
6. Remarcação, lembretes, pagamento de sinal, avaliações, fidelidade, busca por localização (candidatos a ficar fora)

**Proposta inicial (para discussão):** Os 5 primeiros itens dentro; o último grupo fora (ver ADR-0003).

## C4 nível 1 · Contexto

Quem usa o sistema e com quais sistemas externos ele conversa.

<a id="q04"></a>

### Q04 · Quem são os atores (pessoas) do C4 nível 1?

- **Afeta no diagrama:** C4 nível 1: as pessoas e as setas "usa"
- **ADR:** [ADR-0003: Enquadrar o sistema como plataforma multi-tenant de agendamento](adr/0003-enquadramento-plataforma-multi-tenant.md)
- **Prazo:** 10/10 · **Issue:** [#4](https://github.com/Allainn/barbearia-multiplataforma/issues/4)

**Contexto.** Cada pessoa no diagrama vira uma role no Keycloak e um cenário de autorização (403).

**Opções na mesa**

1. Cliente: busca horários, agenda e cancela
2. Profissional (barbeiro): vê a própria agenda
3. Gestor da barbearia: cadastra serviços, profissionais e expediente
4. Administrador da plataforma: aprova barbearias
5. Recepcionista: agenda pelo cliente no balcão (pode ser o próprio gestor)

**Proposta inicial (para discussão):** Os 4 primeiros. A recepcionista fica coberta pelo gestor.

<a id="q05"></a>

### Q05 · Quais sistemas externos aparecem no C4 nível 1?

- **Afeta no diagrama:** C4 nível 1: sistemas externos (cinza); C4 nível 2: setas que saem do sistema
- **ADR:** [ADR-0004: Decomposição em serviços (containers do C4 nível 2)](adr/0004-decomposicao-em-servicos.md) · [ADR-0009: Segurança: Keycloak, OAuth2/OIDC e onde validar o JWT](adr/0009-seguranca-keycloak-e-validacao-jwt.md)
- **Prazo:** 10/10 · **Issue:** [#5](https://github.com/Allainn/barbearia-multiplataforma/issues/5)

**Contexto.** Todo sistema externo desenhado precisa existir na demo, nem que seja simulado (mock).

**Opções na mesa**

1. Keycloak (IdP): obrigatório
2. Provedor de mensagens (WhatsApp, SMS, e-mail ou push): simulado com um mock que só registra o envio
3. Gateway de pagamento (sinal contra no-show): só se entrar no escopo
4. Mapas/geolocalização ou Google Calendar

**Proposta inicial (para discussão):** Keycloak + provedor de mensagens simulado. Pagamento e o resto ficam fora.

<a id="q06"></a>

### Q06 · Os front-ends aparecem no diagrama?

- **Afeta no diagrama:** C4 nível 2: containers de front-end (app do cliente, painel da barbearia)
- **ADR:** [ADR-0004: Decomposição em serviços (containers do C4 nível 2)](adr/0004-decomposicao-em-servicos.md)
- **Prazo:** 10/10 · **Issue:** [#6](https://github.com/Allainn/barbearia-multiplataforma/issues/6)

**Contexto.** Front-end não é avaliado e a demo pode ser com curl/Postman. Mas tudo o que for desenhado precisa ser implementado.

**Opções na mesa**

1. Não desenhar: as pessoas chamam o BFF direto, como no C4 de referência do PizzaExpress
2. Desenhar app-cliente e painel-barbearia marcados como "fora do escopo da implementação"
3. Implementar um front mínimo

**Proposta inicial (para discussão):** Não desenhar e citar na apresentação que o acesso real seria por apps, com demo via curl/Postman.

## C4 nível 2 · Containers

Quais containers existem, em que tecnologia, com quais bancos, e o que significa cada seta (protocolo e propósito).

<a id="q07"></a>

### Q07 · Quais containers (serviços) o sistema terá?

- **Afeta no diagrama:** C4 nível 2 inteiro
- **ADR:** [ADR-0004: Decomposição em serviços (containers do C4 nível 2)](adr/0004-decomposicao-em-servicos.md)
- **Prazo:** 12/10 · **Issue:** [#7](https://github.com/Allainn/barbearia-multiplataforma/issues/7)

**Contexto.** Cada container precisa de um motivo para existir e de um dono no grupo. São 3 semanas e 7 pessoas.

**Opções na mesa**

1. 3 serviços: barbearia, agendamento, notificação
2. 5 containers: bff-gateway, barbearia, agendamento, disponibilidade (lado de leitura do CQRS), notificação
3. 7 ou mais: + pagamento, avaliações, fidelidade

**Proposta inicial (para discussão):** 5 containers (ADR-0004).

<a id="q08"></a>

### Q08 · Quais linguagens, e em quais serviços?

- **Afeta no diagrama:** C4 nível 2: a tecnologia anotada em cada container
- **ADR:** [ADR-0005: Linguagens por serviço](adr/0005-linguagens-por-servico.md)
- **Prazo:** 10/10 · **Issue:** [#8](https://github.com/Allainn/barbearia-multiplataforma/issues/8)

**Contexto.** Precisamos de pelo menos 2 linguagens, com o motivo de cada uma: força da linguagem ou proficiência do grupo. O PizzaExpress tem tudo pronto em Python e Java.

**Opções na mesa**

1. Java (Spring Boot) + Python (FastAPI), reaproveitando o PizzaExpress
2. Java + Go, Node.js/TypeScript ou .NET

**Proposta inicial (para discussão):** Java no bff-gateway e no agendamento-service; Python no barbearia, disponibilidade e notificação (ADR-0005).

**Ação:** Enquete: cada integrante comenta com quais linguagens se sente à vontade.

<a id="q09"></a>

### Q09 · Um BFF para todos os canais ou um por canal? Em qual tecnologia?

- **Afeta no diagrama:** C4 nível 2: container(s) de entrada
- **ADR:** [ADR-0004: Decomposição em serviços (containers do C4 nível 2)](adr/0004-decomposicao-em-servicos.md) · [ADR-0005: Linguagens por serviço](adr/0005-linguagens-por-servico.md)
- **Prazo:** 12/10 · **Issue:** [#9](https://github.com/Allainn/barbearia-multiplataforma/issues/9)

**Contexto.** O BFF adapta respostas ao canal e é onde ficam 401/403 no modelo do professor. A Aula 5 vai aprofundar BFF e resiliência. Cuidado com regra de negócio no BFF (Aula 1).

**Opções na mesa**

1. Um BFF para todos os canais
2. Um BFF por canal (app do cliente × painel da barbearia)
3. API gateway pronto (Spring Cloud Gateway, Kong) + BFF

**Proposta inicial (para discussão):** Um BFF em Java agora; separar por canal fica como evolução depois da Aula 5.

<a id="q10"></a>

### Q10 · Qual broker de mensagens? Quais tópicos e chaves de partição?

- **Afeta no diagrama:** C4 nível 2: container do broker e setas de publicação/consumo
- **ADR:** [ADR-0006: Comunicação síncrona, assíncrona e o broker de eventos (Kafka)](adr/0006-comunicacao-sincrona-e-kafka.md)
- **Prazo:** 12/10 · **Issue:** [#10](https://github.com/Allainn/barbearia-multiplataforma/issues/10)

**Contexto.** Mensageria é obrigatória (ou a justificativa para tudo ser síncrono). Notificações em massa batem em API externa com limite de taxa, e o read model da disponibilidade depende de cada reserva.

**Opções na mesa**

1. Kafka
2. RabbitMQ
3. MQTT
4. Tudo síncrono

**Proposta inicial (para discussão):** Kafka. Tópicos agendamento.criado, agendamento.cancelado e expediente.alterado, com chave profissional_id (ADR-0006).

<a id="q11"></a>

### Q11 · O que é síncrono e o que é assíncrono? (as setas do nível 2)

- **Afeta no diagrama:** C4 nível 2: protocolo e descrição de cada seta
- **ADR:** [ADR-0006: Comunicação síncrona, assíncrona e o broker de eventos (Kafka)](adr/0006-comunicacao-sincrona-e-kafka.md)
- **Prazo:** 12/10 · **Issue:** [#11](https://github.com/Allainn/barbearia-multiplataforma/issues/11)

**Contexto.** O ponto em aberto: ao reservar, o agendamento precisa da duração do serviço e do expediente do profissional, que pertencem ao barbearia-service.

**Opções na mesa**

1. REST síncrono agendamento → barbearia-service, com timeout e circuit breaker
2. Cópia local do expediente no agendamento, alimentada por eventos
3. O BFF busca os dados e manda junto (coloca regra no BFF, o que o professor desaconselha)

**Proposta inicial (para discussão):** REST síncrono com timeout e circuit breaker; a cópia local fica como evolução.

<a id="q12"></a>

### Q12 · Como organizar os bancos de dados?

- **Afeta no diagrama:** C4 nível 2: containers de banco e setas de cada serviço para eles
- **ADR:** [ADR-0011: Dados por serviço e isolamento por barbearia](adr/0011-dados-por-servico.md)
- **Prazo:** 12/10 · **Issue:** [#12](https://github.com/Allainn/barbearia-multiplataforma/issues/12)

**Contexto.** Cada serviço é dono dos seus dados. O ambiente roda na máquina de cada um (8 GB para o Docker). O sistema é multi-tenant.

**Opções na mesa**

1. PostgreSQL único com um schema e um usuário por serviço (como o PizzaExpress)
2. Uma instância de PostgreSQL por serviço
3. Read model da disponibilidade no PostgreSQL ou no Redis
4. Multi-tenancy: coluna barbearia_id (pool) ou schema por barbearia

**Proposta inicial (para discussão):** PostgreSQL único com schema por serviço, read model no PostgreSQL e coluna barbearia_id (ADR-0011).

<a id="q13"></a>

### Q13 · Onde validar o JWT? Como isolar uma barbearia da outra?

- **Afeta no diagrama:** C4 nível 1 (Keycloak); C4 nível 2 (setas de autenticação e validação)
- **ADR:** [ADR-0009: Segurança: Keycloak, OAuth2/OIDC e onde validar o JWT](adr/0009-seguranca-keycloak-e-validacao-jwt.md)
- **Prazo:** 12/10 · **Issue:** [#13](https://github.com/Allainn/barbearia-multiplataforma/issues/13)

**Contexto.** É preciso demonstrar 401 e 403 e justificar o modelo. Sistema multi-tenant com dados pessoais: o gestor da barbearia A não pode mexer na B.

**Opções na mesa**

1. Só no BFF (modelo 1 da Aula 2)
2. Em cada serviço (modelo 2 da Aula 2)
3. Híbrido: o BFF valida tudo e os serviços que escrevem revalidam o token e o tenant

**Proposta inicial (para discussão):** Keycloak + híbrido, com a claim barbearia_id para o 403 entre barbearias (ADR-0009).

<a id="q14"></a>

### Q14 · Como impedir dois clientes no mesmo horário? (lock)

- **Afeta no diagrama:** C4 nível 2 (agendamento-service → PostgreSQL); C4 nível 3 do agendamento
- **ADR:** [ADR-0007: Concorrência na reserva de horário (lock)](adr/0007-concorrencia-na-reserva-de-horario.md)
- **Prazo:** 12/10 · **Issue:** [#14](https://github.com/Allainn/barbearia-multiplataforma/issues/14)

**Contexto.** Pouca escrita (~3 reservas/s no pico), mas com disputa pelo mesmo horário. Várias instâncias atrás de load balancer: lock em memória não resolve.

**Opções na mesa**

1. Lock pessimista (SELECT ... FOR UPDATE)
2. Lock otimista (coluna de versão)
3. Constraint de exclusão no PostgreSQL (sem sobreposição de intervalos por profissional)
4. Serializar os comandos pelo Kafka (abordagem da Aula 3)
5. Lock distribuído no Redis

**Proposta inicial (para discussão):** Constraint de exclusão + 409 Conflict; lock otimista nas mudanças de estado (ADR-0007).

<a id="q15"></a>

### Q15 · CQRS lite ou completo na consulta de disponibilidade?

- **Afeta no diagrama:** C4 nível 2: disponibilidade-service, seu banco e as setas vindas do Kafka
- **ADR:** [ADR-0008: CQRS na consulta de disponibilidade](adr/0008-cqrs-na-consulta-de-disponibilidade.md)
- **Prazo:** 12/10 · **Issue:** [#15](https://github.com/Allainn/barbearia-multiplataforma/issues/15)

**Contexto.** Consultar horários livres é ~50 vezes mais frequente que reservar, e o cálculo é caro. Rodar esse cálculo nas tabelas que têm lock trava o pico.

**Opções na mesa**

1. Sem CQRS: calcular na hora no agendamento
2. CQRS lite: pacotes separados no mesmo serviço e banco
3. CQRS completo: disponibilidade-service com read model próprio alimentado por eventos
4. Cache (Redis) na frente do cálculo

**Proposta inicial (para discussão):** CQRS completo; recuo para o lite se o prazo apertar (ADR-0008).

<a id="q16"></a>

### Q16 · Outbox Pattern entra? Polling ou Debezium?

- **Afeta no diagrama:** C4 nível 2 (seta agendamento → Kafka); C4 nível 3 do agendamento
- **ADR:** [ADR-0012: Garantia de publicação de eventos (Outbox Pattern)](adr/0012-garantia-de-publicacao-outbox.md)
- **Prazo:** 12/10 · **Issue:** [#16](https://github.com/Allainn/barbearia-multiplataforma/issues/16)

**Contexto.** Salvar no banco e publicar no Kafka não é atômico. Sem Outbox, uma falha do Kafka perde o evento da reserva. É desejável, não obrigatório.

**Opções na mesa**

1. Dual write (salva e publica; aceita o risco)
2. Outbox com publicação por polling
3. Outbox com Debezium (CDC)

**Proposta inicial (para discussão):** Outbox com polling no agendamento-service (ADR-0012).

<a id="q17"></a>

### Q17 · Lembretes (véspera e 1 h antes) entram no escopo?

- **Afeta no diagrama:** C4 nível 2: notificacao-service (e um agendador de tarefas, se entrar)
- **ADR:** [ADR-0004: Decomposição em serviços (containers do C4 nível 2)](adr/0004-decomposicao-em-servicos.md)
- **Prazo:** 12/10 · **Issue:** [#17](https://github.com/Allainn/barbearia-multiplataforma/issues/17)

**Contexto.** Lembretes são o maior volume de mensagens e reforçam o argumento da mensageria, mas exigem agendar tarefas para o futuro.

**Opções na mesa**

1. Fora: só confirmação e cancelamento
2. Job no notificacao-service que, a cada minuto, busca no próprio schema os lembretes vencidos
3. Tópico de lembretes com consumo atrasado

**Proposta inicial (para discussão):** Fora da demo; o job (segunda opção) entra se sobrar tempo.

## C4 nível 3 · Componentes

Como cada serviço se organiza por dentro.

<a id="q18"></a>

### Q18 · Clean ou Hexagonal dentro dos serviços? Qual serviço ganha o C4 nível 3?

- **Afeta no diagrama:** C4 nível 3
- **ADR:** [ADR-0010: Arquitetura interna dos serviços](adr/0010-arquitetura-interna-dos-servicos.md)
- **Prazo:** 14/10 · **Issue:** [#18](https://github.com/Allainn/barbearia-multiplataforma/issues/18)

**Contexto.** A arquitetura interna é livre, desde que justificada. O professor prefere Clean para padronizar; aprovou Hexagonal para outro grupo.

**Opções na mesa**

1. Clean em todos
2. Hexagonal em todos
3. Misto: Clean onde há regra de negócio, Hexagonal enxuta nos workers

**Proposta inicial (para discussão):** Clean em todos + DDD tático no agendamento-service; C4 nível 3 do agendamento (ADR-0010).

## Entrega e demo

CI/CD, observabilidade e o roteiro da apresentação.

<a id="q19"></a>

### Q19 · Qual pipeline de CI/CD e onde roda o deploy?

- **Afeta no diagrama:** Diagrama de implantação (se fizermos) e a parte de CI/CD da demo
- **ADR:** [ADR-0013: Entrega contínua e observabilidade](adr/0013-entrega-continua-e-observabilidade.md)
- **Prazo:** 14/10 · **Issue:** [#19](https://github.com/Allainn/barbearia-multiplataforma/issues/19)

**Contexto.** A demo precisa mostrar código alterado → pipeline → publicação → chamada → Grafana. Os runners do GitHub Actions não alcançam o Minikube local. Depende do que a Aula 4 (07/10) mostrar.

**Opções na mesa**

1. GitHub Actions + GHCR + Argo CD no Minikube (GitOps, modelo pull)
2. GitHub Actions com runner self-hosted + docker compose
3. Woodpecker CI ou GitLab CI local

**Proposta inicial (para discussão):** Preliminar: GitHub Actions + GHCR + Argo CD no Minikube. Revisar com o material da Aula 4.

<a id="q20"></a>

### Q20 · O que mostrar de observabilidade?

- **Afeta no diagrama:** C4 nível 2 (stack de observabilidade, se for desenhada); demo
- **ADR:** [ADR-0013: Entrega contínua e observabilidade](adr/0013-entrega-continua-e-observabilidade.md)
- **Prazo:** 14/10 · **Issue:** [#20](https://github.com/Allainn/barbearia-multiplataforma/issues/20)

**Contexto.** O PizzaExpress já traz OpenTelemetry nos serviços e Prometheus, Loki, Tempo e Grafana com dashboards.

**Opções na mesa**

1. Reaproveitar a stack do PizzaExpress como está
2. Reaproveitar + propagar o trace pelo Kafka (um trace do BFF até a notificação)
3. Desenhar a stack no C4 nível 2 ou só citar

**Proposta inicial (para discussão):** Reaproveitar a stack, propagar o trace pelo Kafka e mostrar a latência da reserva no Grafana.

<a id="q21"></a>

### Q21 · Qual o roteiro da demo e quem apresenta cada parte?

- **Afeta no diagrama:** Apresentação
- **Prazo:** 24/10 · **Issue:** [#21](https://github.com/Allainn/barbearia-multiplataforma/issues/21)

**Contexto.** São 20 minutos no total; a sugestão é 8 de demo. Pode ser gravada.

**Opções na mesa**

1. Ao vivo
2. Gravada (menos risco de falha de ambiente)
3. Híbrido: decisões ao vivo e demo gravada

**Proposta inicial (para discussão):** Sequência: login → 401/403 → consulta de horários → reserva → disputa 409 → evento no Kafka UI → notificação → horário some da consulta → commit → pipeline → Grafana.

## Organização do grupo

Papéis, convenções e ferramentas.

<a id="q22"></a>

### Q22 · Qual o papel de cada integrante?

- **Afeta no diagrama:** Dono de cada container do C4 nível 2
- **Prazo:** 10/10 · **Issue:** [#22](https://github.com/Allainn/barbearia-multiplataforma/issues/22)

**Contexto.** Somos 7. A Aula 1 fez a ponte com Team Topologies: times alinhados a um fluxo (um serviço) e um time de plataforma.

**Opções na mesa**

1. Arquitetura, C4, ADRs e slides (1 pessoa)
2. Segurança: Keycloak + bff-gateway (1)
3. agendamento-service: DDD, lock, Outbox (2)
4. barbearia-service + disponibilidade-service: CQRS (2)
5. notificacao-service + plataforma: compose, CI/CD, observabilidade (1)

**Proposta inicial (para discussão):** A divisão listada nas opções (1 + 1 + 2 + 2 + 1 pessoas). Cada um comenta a primeira e a segunda opção de papel.

<a id="q23"></a>

### Q23 · Convenções: quórum de ADR, idioma do código, commits

- **Afeta no diagrama:** Nomes de containers, tópicos e endpoints no diagrama
- **ADR:** [ADR-0001: Registrar as decisões arquiteturais com ADRs](adr/0001-registrar-decisoes-com-adr.md) · [ADR-0002: Monorepo e estrutura de pastas](adr/0002-monorepo-e-estrutura.md)
- **Prazo:** 10/10 · **Issue:** [#23](https://github.com/Allainn/barbearia-multiplataforma/issues/23)

**Contexto.** O PizzaExpress está em inglês. O DDD pede a linguagem do negócio (ubíqua), que aqui é português.

**Opções na mesa**

1. Quórum: 4 aprovações no PR, ou 48 h sem objeção
2. Código: domínio em português (Agendamento, Barbearia) e termos técnicos em inglês (Repository, UseCase, Controller)
3. Código todo em inglês
4. Commits no padrão Conventional Commits; main protegida

**Proposta inicial (para discussão):** Quórum de 4 aprovações ou 48 h; domínio em português e termos técnicos em inglês; Conventional Commits.

<a id="q24"></a>

### Q24 · Onde fica o diagrama oficial?

- **Afeta no diagrama:** Todos os diagramas
- **Prazo:** 14/10 · **Issue:** [#24](https://github.com/Allainn/barbearia-multiplataforma/issues/24)

**Contexto.** O esboço está no Miro, que é bom para discutir junto. O professor usa draw.io com a notação C4.

**Opções na mesa**

1. Miro como fonte até o fim
2. Miro para discutir; versão final em draw.io dentro do repositório (versionada, com export PNG para os slides)
3. Diagrama como código (Structurizr DSL ou Mermaid) no repositório

**Proposta inicial (para discussão):** Miro para discutir agora; versão final em draw.io em docs/arquitetura, com o Mermaid do repositório como espelho de texto.
