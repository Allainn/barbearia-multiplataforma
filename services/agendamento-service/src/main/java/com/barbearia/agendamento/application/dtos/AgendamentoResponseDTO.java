package com.barbearia.agendamento.application.dtos;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Resposta do POST /agendamentos. Os horários vão como texto ISO com offset
 * (2026-10-28T18:00:00-03:00), no mesmo formato dos eventos.
 */
public record AgendamentoResponseDTO(
        UUID id,
        @JsonProperty("barbearia_id") UUID barbeariaId,
        @JsonProperty("profissional_id") UUID profissionalId,
        @JsonProperty("servico_id") UUID servicoId,
        @JsonProperty("cliente_id") String clienteId,
        String inicio,
        String fim,
        String status) {

    public static AgendamentoResponseDTO from(Agendamento agendamento) {
        return new AgendamentoResponseDTO(
                agendamento.getId(),
                agendamento.getBarbeariaId(),
                agendamento.getProfissionalId(),
                agendamento.getServicoId(),
                agendamento.getClienteId(),
                agendamento.getInicio().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME),
                agendamento.getFim().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME),
                agendamento.getStatus().name());
    }
}
