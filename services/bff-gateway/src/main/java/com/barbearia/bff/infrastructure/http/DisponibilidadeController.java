package com.barbearia.bff.infrastructure.http;

import com.barbearia.bff.infrastructure.clients.DisponibilidadeClient;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** GET /disponibilidade?profissional_id=...&data=... para qualquer usuário logado. A query string vai como veio. */
@RestController
public class DisponibilidadeController {

    private final DisponibilidadeClient client;

    public DisponibilidadeController(DisponibilidadeClient client) {
        this.client = client;
    }

    @GetMapping("/disponibilidade")
    public ResponseEntity<String> consultar(HttpServletRequest requisicao, Authentication usuario) {
        return client.encaminhar(requisicao, null, usuario.getName());
    }
}
