package com.barbearia.agendamento.domain.exceptions;

/** O profissional já tem um agendamento confirmado que se sobrepõe ao horário pedido. Vira 409. */
public class HorarioIndisponivelException extends RuntimeException {

    public HorarioIndisponivelException() {
        super("Horário indisponível para este profissional");
    }
}
