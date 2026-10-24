package com.barbearia.agendamento.domain.valueobjects;

/** Só CONFIRMADO ocupa o horário: a constraint de exclusão ignora os cancelados. */
public enum StatusAgendamento {
    CONFIRMADO,
    CANCELADO
}
