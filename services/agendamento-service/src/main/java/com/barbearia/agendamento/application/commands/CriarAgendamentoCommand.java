package com.barbearia.agendamento.application.commands;

import java.time.OffsetDateTime;
import java.util.UUID;

public record CriarAgendamentoCommand(
        UUID barbeariaId,
        UUID profissionalId,
        UUID servicoId,
        String clienteId,
        OffsetDateTime inicio,
        OffsetDateTime fim) {
}
