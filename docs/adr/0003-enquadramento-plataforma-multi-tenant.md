# ADR-0003: Enquadrar o sistema como plataforma multi-tenant de agendamento

- **Status:** Aceito
- **Data:** 24/10/2026
- **Questão:** [Q01](../questoes-abertas.md#q01) · [Q02](../questoes-abertas.md#q02) · [Q03](../questoes-abertas.md#q03) · [Q04](../questoes-abertas.md#q04)
- **Afeta no diagrama:** C4 nível 1 inteiro (quem usa, o que o sistema faz, sistemas externos)

## Contexto

- A ideia inicial do grupo é um **sistema de agendamento de barbearia**.
- O professor descartou sistemas pequenos: precisa de volume de uso que justifique a arquitetura; uma "padaria de bairro" não serve (Aula 3 · P3 [00:56:42]). Ele também disse que lock resolve uma pizzaria de bairro de ~300 pedidos/dia, e que CQRS e Kafka só se justificam com volumetria alta (Aula 3 · P2 [00:20:40], P2 [00:40:55]).
- A agenda de **uma** barbearia não tem esse volume. Precisamos de um recorte em que o volume exista de verdade.

## Opções consideradas

### A. Sistema para uma barbearia ou uma rede pequena

- **Prós:** domínio simples.
- **Contras:** volume de "padaria de bairro"; não justifica Kafka nem CQRS. Descartado pelo critério do professor.

### B. SaaS multi-tenant: muitas barbearias usam a mesma plataforma para gerir a agenda

- **Prós:** volume vem da soma das barbearias; isolamento por barbearia (tenant) vira um tema de segurança (403 entre barbearias).
- **Contras:** cada cliente só enxerga a barbearia do link; a leitura pesada fica menor.

### C. Marketplace multi-tenant: B + o cliente busca horários em qualquer barbearia da plataforma

- **Prós:** além do volume somado, a **busca de horários livres** em muitas barbearias vira a operação mais frequente do sistema, muito mais do que reservar. Isso justifica CQRS no lado de leitura. As confirmações em massa justificam mensageria (limite de taxa da API externa de mensagens, o caso do erro 429 da Aula 3).
- **Contras:** escopo maior. Precisa cortar funcionalidades (ver "Fora do escopo").

## Decisão

Opção **C**, votada na Q01: plataforma marketplace multi-tenant, inspirada em produtos como Booksy e Trinks. Nome votado na Q02: **BarberHub**.

### Volumetria assumida

São hipóteses de mercado para o pitch, não medições. Entram no slide de abertura e não foram provadas com teste de carga.

| Métrica | Valor assumido | Como chegamos |
|---|---|---|
| Barbearias ativas | 5.000 | — |
| Profissionais | 25.000 | média de 5 por barbearia |
| Clientes cadastrados | 2 milhões | — |
| Agendamentos por dia | 150.000 | 6 por profissional por dia |
| Consultas de disponibilidade por dia | 7,5 milhões | 50 consultas para cada agendamento (o cliente compara horários, profissionais e barbearias) |
| Notificações por dia | 150.000 ou mais | uma confirmação por agendamento, mais uma para cada cancelamento; com os lembretes de véspera e de 1 h antes, que ficaram fora, seriam 450.000 |
| Pico de leitura | ~130 req/s, com rajadas de ~1.300 req/s | 25% das consultas em 4 h de pico (sexta à tarde, sábado de manhã); rajada ×10 quando um profissional abre a agenda da semana |
| Pico de escrita | ~3 reservas/s | 25% dos agendamentos nas mesmas 4 h |

**Leitura dos números:** a escrita é pequena em quantidade, mas tem **disputa pelo mesmo horário** (vários clientes tentando o mesmo profissional às 18h de sexta). A leitura é de 50 a 500 vezes maior que a escrita. Isso orienta duas decisões separadas:

- Concorrência na escrita: [ADR-0007](0007-concorrencia-na-reserva-de-horario.md) (lock com constraint de exclusão).
- Escala da leitura: [ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md) (CQRS).

### Escopo da demo

Na Q03, o grupo aprovou os cinco itens da proposta. O [roadmap](../roadmap.md) de 21/10 manteve os cinco e tirou o expediente do primeiro:

1. O gestor cadastra barbearias, profissionais e serviços (duração e preço).
2. O cliente consulta os horários livres de um profissional num dia: grade fixa das 09:00 às 18:00, em blocos de 30 min ([ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md)).
3. O cliente reserva um horário; na disputa pelo mesmo horário, quem chega depois recebe 409 ([ADR-0007](0007-concorrencia-na-reserva-de-horario.md)).
4. O cliente cancela a própria reserva.
5. O sistema manda a confirmação e o cancelamento por um provedor de mensagens simulado, que grava no log ([ADR-0006](0006-comunicacao-sincrona-e-kafka.md)).

Na demo, o marketplace aparece como navegação: o cliente lista todas as barbearias da plataforma, escolhe um profissional e consulta os horários dele. Uma busca agregada (por região, serviço ou horário em várias barbearias de uma vez) fica como evolução.

**Atores (Q04):** o grupo votou Cliente, Profissional, Gestor e Administrador da plataforma. O roadmap manteve só **Cliente** e **Gestor da barbearia**, os dois que têm rotas e roles no Keycloak.

### Fora do escopo

Cortado pelo roadmap: expediente configurável e folgas, remarcação, lembretes, front-end (a demo usa curl), busca agregada e por geolocalização, pagamento e sinal antecipado, avaliações e fidelidade. Tudo o que está no C4 está implementado.

## Consequências

- O C4 nível 1 tem os atores Cliente e Gestor da barbearia e os sistemas externos Keycloak e provedor de mensagens.
- Todo dado do domínio carrega `barbearia_id`, no modelo pool ([ADR-0011](0011-dados-por-servico.md)).
- **Trade-off aceito:** o isolamento entre barbearias não é garantido na segurança. O 403 entre barbearias ficou fora por prazo ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)), então um gestor autenticado consegue cadastrar profissional ou serviço em outra barbearia. A evolução é o token do gestor carregar a barbearia dele e o serviço comparar com a da rota.
- A volumetria justifica as duas decisões de dados: lock na escrita e CQRS na leitura.

## Referências

- Aula 3 · P3 [00:56:42]: sistema grande, não uma "padaria de bairro".
- Aula 3 · P2 [00:20:40]: lock resolve sistemas pequenos; volumetria alta trava o banco.
- Aula 3 · P2 [00:40:55]: Kafka só com volumetria alta; desacoplar de API externa com rate limit.
- Votações: [Q01 (#1)](https://github.com/Allainn/barbearia-multiplataforma/issues/1), [Q02 (#2)](https://github.com/Allainn/barbearia-multiplataforma/issues/2), [Q03 (#3)](https://github.com/Allainn/barbearia-multiplataforma/issues/3), [Q04 (#4)](https://github.com/Allainn/barbearia-multiplataforma/issues/4).
