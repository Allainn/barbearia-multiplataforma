package com.barbearia.agendamento.application.commands;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;
import com.barbearia.agendamento.application.ports.EventPublisher;

import java.time.Clock;

/**
 * Cancela e publica agendamento.cancelado. Só o cliente que fez o agendamento cancela, e essa
 * regra fica no aggregate. Cancelar um já cancelado não publica de novo,
 * nem quando dois DELETEs chegam ao mesmo tempo: só publica quem mudou a linha no banco.
 */
public class CancelarAgendamentoHandler {

    private final AgendamentoRepository repository;
    private final EventPublisher producer;
    private final Clock clock;

    public CancelarAgendamentoHandler(AgendamentoRepository repository, EventPublisher producer, Clock clock) {
        this.repository = repository;
        this.producer = producer;
        this.clock = clock;
    }

    public void handle(CancelarAgendamentoCommand command) {
        Agendamento agendamento = repository.findById(command.agendamentoId())
                .orElseThrow(() -> new AgendamentoNotFoundException(command.agendamentoId()));
        if (agendamento.cancelar(command.clienteId(), clock.instant()) && repository.updateStatus(agendamento)) {
            agendamento.pullDomainEvents().forEach(producer::publish);
        }
    }
}
