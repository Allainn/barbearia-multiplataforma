package com.barbearia.agendamento.domain.events;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Eventos do aggregate Agendamento. Os dois carregam os mesmos dados (o payload do
 * envelope do contrato); muda só o nome, que também é o nome do tópico no Kafka.
 * Sealed para o KafkaEventProducer tratar os dois casos sem cair num "else" genérico.
 */
public sealed interface DomainEvent permits AgendamentoCriado, AgendamentoCancelado {

    String eventName();

    Instant ocorridoEm();

    UUID agendamentoId();

    UUID barbeariaId();

    UUID profissionalId();

    String clienteId();

    OffsetDateTime inicio();

    OffsetDateTime fim();
}
