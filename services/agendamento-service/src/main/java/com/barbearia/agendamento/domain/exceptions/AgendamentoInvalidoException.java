package com.barbearia.agendamento.domain.exceptions;

/**
 * O pedido fere uma regra do agendamento: intervalo invertido, horário no passado ou valor que
 * não cabe na tabela. Vira 422.
 */
public class AgendamentoInvalidoException extends RuntimeException {

    public AgendamentoInvalidoException(String message) {
        super(message);
    }
}
