package com.barbearia.agendamento.domain.events;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.UUID;

public record AgendamentoCriado(
        UUID agendamentoId,
        UUID barbeariaId,
        UUID profissionalId,
        String clienteId,
        OffsetDateTime inicio,
        OffsetDateTime fim,
        Instant ocorridoEm) implements DomainEvent {

    @Override
    public String eventName() {
        return "agendamento.criado";
    }
}
