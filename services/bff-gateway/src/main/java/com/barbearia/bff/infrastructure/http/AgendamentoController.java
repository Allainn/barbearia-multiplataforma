package com.barbearia.bff.infrastructure.http;

import com.barbearia.bff.infrastructure.clients.AgendamentoClient;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Rotas do agendamento-service, só para cliente (RegrasDeAutorizacao). O cliente_id da reserva
 * é sempre o sub do token, levado no X-User-ID: o corpo não escolhe em nome de quem reserva.
 * A regra "só o dono cancela" fica no agendamento-service, que é quem tem o dado (ADR-0015).
 */
@RestController
@RequestMapping("/agendamentos")
public class AgendamentoController {

    private final AgendamentoClient client;

    public AgendamentoController(AgendamentoClient client) {
        this.client = client;
    }

    @PostMapping
    public ResponseEntity<String> reservar(HttpServletRequest requisicao, Authentication usuario,
                                           @RequestBody(required = false) String corpo) {
        return client.encaminhar(requisicao, corpo, usuario.getName());
    }

    @DeleteMapping("/{agendamentoId}")
    public ResponseEntity<String> cancelar(HttpServletRequest requisicao, Authentication usuario) {
        return client.encaminhar(requisicao, null, usuario.getName());
    }
}
