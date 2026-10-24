package com.barbearia.agendamento.application.commands;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;
import com.barbearia.agendamento.application.ports.EventPublisher;

import java.time.Clock;

/**
 * Command Handler da reserva. Grava primeiro e só publica depois que o INSERT deu certo;
 * se a constraint recusar, HorarioIndisponivelException sobe e nenhum evento sai.
 * Sem Outbox (ADR-0012): se o serviço cair entre o INSERT e o envio, o evento se perde.
 */
public class CriarAgendamentoHandler {

    private final AgendamentoRepository repository;
    private final EventPublisher producer;
    private final Clock clock;

    public CriarAgendamentoHandler(AgendamentoRepository repository, EventPublisher producer, Clock clock) {
        this.repository = repository;
        this.producer = producer;
        this.clock = clock;
    }

    public Agendamento handle(CriarAgendamentoCommand command) {
        Agendamento agendamento = Agendamento.criar(
                command.barbeariaId(), command.profissionalId(), command.servicoId(), command.clienteId(),
                command.inicio(), command.fim(), clock.instant());
        repository.insert(agendamento);
        agendamento.pullDomainEvents().forEach(producer::publish);
        return agendamento;
    }
}
