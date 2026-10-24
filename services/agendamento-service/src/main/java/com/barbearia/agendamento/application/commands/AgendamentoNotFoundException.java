package com.barbearia.agendamento.application.commands;

import java.util.UUID;

public class AgendamentoNotFoundException extends RuntimeException {

    public AgendamentoNotFoundException(UUID id) {
        super("Agendamento '" + id + "' não encontrado.");
    }
}
