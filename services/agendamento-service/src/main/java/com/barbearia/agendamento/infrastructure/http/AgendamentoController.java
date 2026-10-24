package com.barbearia.agendamento.infrastructure.http;

import com.barbearia.agendamento.application.commands.CancelarAgendamentoCommand;
import com.barbearia.agendamento.application.commands.CancelarAgendamentoHandler;
import com.barbearia.agendamento.application.commands.CriarAgendamentoCommand;
import com.barbearia.agendamento.application.commands.CriarAgendamentoHandler;
import com.barbearia.agendamento.application.dtos.AgendamentoResponseDTO;
import com.barbearia.agendamento.application.dtos.CriarAgendamentoDTO;
import com.barbearia.agendamento.domain.entities.Agendamento;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.util.UUID;

/**
 * Rotas HTTP do agendamento (contrato em docs/tarefas.md). Não valida token: quem
 * chama é o BFF, que já validou o JWT e repassa o sub no header X-User-ID (ADR-0009).
 * O X-User-ID vira o cliente_id no POST, e no DELETE só o cliente que reservou cancela.
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

    /**
     * Com o produces, o Spring recusa com 406 um Accept que não aceita JSON antes de chamar o
     * handler. Sem ele, a reserva era gravada e publicada, e só a escrita da resposta falhava.
     */
    @PostMapping(produces = MediaType.APPLICATION_JSON_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public AgendamentoResponseDTO criar(
            @Valid @RequestBody CriarAgendamentoDTO body,
            @RequestHeader("X-User-ID") String clienteId) {
        exigirClienteId(clienteId);
        Agendamento agendamento = criarAgendamentoHandler.handle(new CriarAgendamentoCommand(
                body.barbeariaId(), body.profissionalId(), body.servicoId(), clienteId, body.inicio(), body.fim()));
        return AgendamentoResponseDTO.from(agendamento);
    }

    /** Só o cliente que fez o agendamento cancela. Para os outros, a resposta é 404. */
    @DeleteMapping("/{agendamentoId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancelar(@PathVariable UUID agendamentoId, @RequestHeader("X-User-ID") String clienteId) {
        exigirClienteId(clienteId);
        cancelarAgendamentoHandler.handle(new CancelarAgendamentoCommand(agendamentoId, clienteId));
    }

    /**
     * O Spring só recusa o header ausente. Vazio chegaria ao handler como um cliente "". No POST
     * ele seria gravado assim, e no DELETE seria comparado com o dono.
     */
    private static void exigirClienteId(String clienteId) {
        if (clienteId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Header X-User-ID ausente.");
        }
    }
}
