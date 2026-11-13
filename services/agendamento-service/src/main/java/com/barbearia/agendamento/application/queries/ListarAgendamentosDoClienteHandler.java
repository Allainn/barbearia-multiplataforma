package com.barbearia.agendamento.application.queries;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;

import java.util.List;

/**
 * Lista os agendamentos de um cliente, os confirmados e os cancelados. É só leitura: não publica
 * evento nem muda o estado. O cliente nunca vê o agendamento de outro, porque a consulta já filtra
 * pelo X-User-ID que o BFF pôs no pedido.
 */
public class ListarAgendamentosDoClienteHandler {

    private final AgendamentoRepository repository;

    public ListarAgendamentosDoClienteHandler(AgendamentoRepository repository) {
        this.repository = repository;
    }

    public List<Agendamento> handle(String clienteId) {
        return repository.findByClienteId(clienteId);
    }
}
