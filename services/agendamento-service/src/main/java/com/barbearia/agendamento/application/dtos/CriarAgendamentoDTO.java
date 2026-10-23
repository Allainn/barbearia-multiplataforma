package com.barbearia.agendamento.application.dtos;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Corpo do POST /agendamentos, como no contrato (docs/tarefas.md). */
public record CriarAgendamentoDTO(
        @NotNull @JsonProperty("barbearia_id") UUID barbeariaId,
        @NotNull @JsonProperty("profissional_id") UUID profissionalId,
        @NotNull @JsonProperty("servico_id") UUID servicoId,
        @NotNull OffsetDateTime inicio,
        @NotNull OffsetDateTime fim) {
}
