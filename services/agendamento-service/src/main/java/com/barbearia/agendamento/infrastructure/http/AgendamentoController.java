package com.barbearia.agendamento.infrastructure.http;

import com.barbearia.agendamento.application.commands.CancelarAgendamentoHandler;
import com.barbearia.agendamento.application.commands.CriarAgendamentoCommand;
import com.barbearia.agendamento.application.commands.CriarAgendamentoHandler;
import com.barbearia.agendamento.application.dtos.AgendamentoResponseDTO;
import com.barbearia.agendamento.application.dtos.CriarAgendamentoDTO;
import com.barbearia.agendamento.domain.entities.Agendamento;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

/**
 * Rotas HTTP do agendamento (contrato em docs/tarefas.md). Não valida token: quem
 * chama é o BFF, que já validou o JWT e repassa o sub no header X-User-ID (ADR-0009).
 */
@RestController
@RequestMapping("/agendamentos")
public class AgendamentoController {

    private final CriarAgendamentoHandler criarAgendamentoHandler;
    private final CancelarAgendamentoHandler cancelarAgendamentoHandler;

    public AgendamentoController(
            CriarAgendamentoHandler criarAgendamentoHandler,
            CancelarAgendamentoHandler cancelarAgendamentoHandler) {
        this.criarAgendamentoHandler = criarAgendamentoHandler;
        this.cancelarAgendamentoHandler = cancelarAgendamentoHandler;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AgendamentoResponseDTO criar(
            @Valid @RequestBody CriarAgendamentoDTO body,
            @RequestHeader("X-User-ID") String clienteId) {
        Agendamento agendamento = criarAgendamentoHandler.handle(new CriarAgendamentoCommand(
                body.barbeariaId(), body.profissionalId(), body.servicoId(), clienteId, body.inicio(), body.fim()));
        return AgendamentoResponseDTO.from(agendamento);
    }

    @DeleteMapping("/{agendamentoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelar(@PathVariable UUID agendamentoId) {
        cancelarAgendamentoHandler.handle(agendamentoId);
    }
}
