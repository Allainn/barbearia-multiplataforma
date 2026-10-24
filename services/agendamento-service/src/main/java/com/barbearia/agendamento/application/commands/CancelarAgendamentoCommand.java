package com.barbearia.agendamento.application.commands;

import java.util.UUID;

public record CancelarAgendamentoCommand(UUID agendamentoId, String clienteId) {
}
