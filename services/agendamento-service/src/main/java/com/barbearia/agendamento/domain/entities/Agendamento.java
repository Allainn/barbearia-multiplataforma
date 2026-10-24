package com.barbearia.agendamento.domain.entities;

import com.barbearia.agendamento.domain.events.AgendamentoCancelado;
import com.barbearia.agendamento.domain.events.AgendamentoCriado;
import com.barbearia.agendamento.domain.events.DomainEvent;
import com.barbearia.agendamento.domain.exceptions.AgendamentoInvalidoException;
import com.barbearia.agendamento.domain.valueobjects.StatusAgendamento;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Aggregate root do agendamento. Valida as regras que não dependem de disputa
 * (intervalo válido, horário no futuro). A regra "dois agendamentos não se sobrepõem
 * para o mesmo profissional" não fica aqui: quem garante é a constraint de exclusão
 * do PostgreSQL (ADR-0007), porque só o banco enxerga as transações concorrentes.
 */
public class Agendamento {

    /** Horários sempre em America/Sao_Paulo, como no contrato. */
    public static final ZoneId FUSO = ZoneId.of("America/Sao_Paulo");

    private final UUID id;
    private final UUID barbeariaId;
    private final UUID profissionalId;
    private final UUID servicoId;
    private final String clienteId;
    private final OffsetDateTime inicio;
    private final OffsetDateTime fim;
    private StatusAgendamento status;
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    private Agendamento(UUID id, UUID barbeariaId, UUID profissionalId, UUID servicoId, String clienteId,
                        OffsetDateTime inicio, OffsetDateTime fim, StatusAgendamento status) {
        this.id = id;
        this.barbeariaId = barbeariaId;
        this.profissionalId = profissionalId;
        this.servicoId = servicoId;
        this.clienteId = clienteId;
        this.inicio = noFuso(inicio);
        this.fim = noFuso(fim);
        this.status = status;
    }

    /** Cria um agendamento CONFIRMADO e emite AgendamentoCriado. */
    public static Agendamento criar(UUID barbeariaId, UUID profissionalId, UUID servicoId, String clienteId,
                                    OffsetDateTime inicio, OffsetDateTime fim, Instant agora) {
        if (!fim.isAfter(inicio)) {
            throw new AgendamentoInvalidoException("O fim do agendamento precisa ser depois do início.");
        }
        if (!inicio.toInstant().isAfter(agora)) {
            throw new AgendamentoInvalidoException("O agendamento precisa ser num horário futuro.");
        }
        Agendamento agendamento = new Agendamento(UUID.randomUUID(), barbeariaId, profissionalId, servicoId,
                clienteId, inicio, fim, StatusAgendamento.CONFIRMADO);
        agendamento.domainEvents.add(new AgendamentoCriado(agendamento.id, barbeariaId, profissionalId,
                clienteId, agendamento.inicio, agendamento.fim, agora));
        return agendamento;
    }

    /** Reidrata um agendamento já persistido, sem eventos. */
    public static Agendamento reconstruir(UUID id, UUID barbeariaId, UUID profissionalId, UUID servicoId,
                                          String clienteId, OffsetDateTime inicio, OffsetDateTime fim,
                                          StatusAgendamento status) {
        return new Agendamento(id, barbeariaId, profissionalId, servicoId, clienteId, inicio, fim, status);
    }

    /**
     * Cancela e emite AgendamentoCancelado. Cancelar de novo não faz nada e não emite
     * outro evento, para o DELETE poder ser repetido.
     *
     * @return true se o status mudou
     */
    public boolean cancelar(Instant agora) {
        if (status == StatusAgendamento.CANCELADO) {
            return false;
        }
        status = StatusAgendamento.CANCELADO;
        domainEvents.add(new AgendamentoCancelado(id, barbeariaId, profissionalId, clienteId, inicio, fim, agora));
        return true;
    }

    /** Devolve os eventos pendentes e limpa a fila interna. */
    public List<DomainEvent> pullDomainEvents() {
        List<DomainEvent> events = new ArrayList<>(domainEvents);
        domainEvents.clear();
        return events;
    }

    private static OffsetDateTime noFuso(OffsetDateTime horario) {
        return horario.atZoneSameInstant(FUSO).toOffsetDateTime();
    }

    public UUID getId() {
        return id;
    }

    public UUID getBarbeariaId() {
        return barbeariaId;
    }

    public UUID getProfissionalId() {
        return profissionalId;
    }

    public UUID getServicoId() {
        return servicoId;
    }

    public String getClienteId() {
        return clienteId;
    }

    public OffsetDateTime getInicio() {
        return inicio;
    }

    public OffsetDateTime getFim() {
        return fim;
    }

    public StatusAgendamento getStatus() {
        return status;
    }
}
