package com.barbearia.agendamento.domain.repositories;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.barbearia.agendamento.domain.exceptions.HorarioIndisponivelException;

import java.util.Optional;
import java.util.UUID;

public interface AgendamentoRepository {

    /** Grava um agendamento novo. */
    void insert(Agendamento agendamento) throws HorarioIndisponivelException;

    /** Grava o status novo. Devolve false se outro pedido já tinha gravado esse status. */
    boolean updateStatus(Agendamento agendamento);

    Optional<Agendamento> findById(UUID id);
}
