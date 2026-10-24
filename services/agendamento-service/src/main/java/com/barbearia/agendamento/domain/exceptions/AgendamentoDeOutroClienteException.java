package com.barbearia.agendamento.domain.exceptions;

import java.util.UUID;

/**
 * O cliente do pedido não é quem fez o agendamento. Vira 404, a mesma resposta de um agendamento
 * inexistente, para o cliente não descobrir ids de reservas alheias.
 */
public class AgendamentoDeOutroClienteException extends RuntimeException {

    private final UUID agendamentoId;

    public AgendamentoDeOutroClienteException(UUID agendamentoId, String clienteId) {
        super("O agendamento '" + agendamentoId + "' não é do cliente '" + clienteId + "'.");
        this.agendamentoId = agendamentoId;
    }

    public UUID getAgendamentoId() {
        return agendamentoId;
    }
}
