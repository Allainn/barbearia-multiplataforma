# ADR-0003: Enquadrar o sistema como plataforma multi-tenant de agendamento

- **Status:** Proposto
- **Data:** 07/10/2026
- **Questão:** [Q01](../questoes-abertas.md#q01) · [Q03](../questoes-abertas.md#q03)
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

- **Prós:** além do volume somado, a **busca de horários livres** em muitas barbearias vira a operação mais frequente do sistema, muito mais do que reservar. Isso justifica CQRS no lado de leitura. Os lembretes e confirmações em massa justificam mensageria (limite de taxa da API externa de mensagens, o caso do erro 429 da Aula 3).
- **Contras:** escopo maior. Precisa cortar funcionalidades (ver "Fora do escopo").

## Decisão

**Proposta:** opção C, plataforma marketplace multi-tenant, inspirada em produtos como Booksy e Trinks.

### Volumetria assumida (hipóteses para o pitch; validar com o grupo)

| Métrica | Valor assumido | Como chegamos |
|---|---|---|
| Barbearias ativas | 5.000 | — |
| Profissionais | 25.000 | média de 5 por barbearia |
| Clientes cadastrados | 2 milhões | — |
| Agendamentos por dia | 150.000 | 6 por profissional por dia |
| Consultas de disponibilidade por dia | 7,5 milhões | 50 consultas para cada agendamento (o cliente compara horários, profissionais e barbearias) |
| Notificações por dia | 450.000 | 3 por agendamento: confirmação, lembrete de véspera e lembrete 1 h antes |
| Pico de leitura | ~130 req/s, com rajadas de ~1.300 req/s | 25% das consultas em 4 h de pico (sexta à tarde, sábado de manhã); rajada ×10 quando um profissional abre a agenda da semana |
| Pico de escrita | ~3 reservas/s | 25% dos agendamentos nas mesmas 4 h |

**Leitura dos números:** a escrita é pequena em quantidade, mas tem **disputa pelo mesmo horário** (vários clientes tentando o mesmo profissional às 18h de sexta). A leitura é de 50 a 500 vezes maior que a escrita. Isso orienta duas decisões separadas:

- Concorrência na escrita: [ADR-0007](0007-concorrencia-na-reserva-de-horario.md) (lock).
- Escala da leitura: [ADR-0008](0008-cqrs-na-consulta-de-disponibilidade.md) (CQRS).

### Escopo mínimo da demo (proposta)

1. Gestor cadastra barbearia, profissionais, serviços (duração e preço) e expediente.
2. Cliente consulta horários livres de uma barbearia, serviço e data.
3. Cliente agenda um horário; a disputa pelo mesmo horário devolve 409 para quem chegou depois.
4. Cliente cancela.
5. O sistema envia a confirmação e o cancelamento por um provedor de mensagens (simulado).

### Fora do escopo (proposta)

Pagamento e sinal antecipado, avaliações, fidelidade, busca por geolocalização, front-ends (a demo usa curl/Postman). Cada item pode voltar se o grupo quiser, mas tudo o que entrar no diagrama precisa ser implementado.

## Consequências

- O C4 nível 1 ganha os atores **Cliente**, **Profissional**, **Gestor da barbearia** e **Administrador da plataforma**.
- Todo dado do domínio carrega `barbearia_id` (tenant). O isolamento entre barbearias entra no modelo de segurança ([ADR-0009](0009-seguranca-keycloak-e-validacao-jwt.md)).
- Os números acima entram no slide de abertura como justificativa; não precisam ser provados com teste de carga.

## Perguntas para o grupo

- Marketplace (C) ou só SaaS (B)?
- Os números de volumetria estão razoáveis? Alguém tem dado real de mercado para trocar as hipóteses?
- O escopo mínimo está bom? Falta ou sobra algo?
- Nome do produto ([Q02](../questoes-abertas.md#q02)).

## Referências

- Aula 3 · P3 [00:56:42]: sistema grande, não uma "padaria de bairro".
- Aula 3 · P2 [00:20:40]: lock resolve sistemas pequenos; volumetria alta trava o banco.
- Aula 3 · P2 [00:40:55]: Kafka só com volumetria alta; desacoplar de API externa com rate limit.
