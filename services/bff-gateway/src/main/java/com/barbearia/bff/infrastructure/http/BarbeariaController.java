package com.barbearia.bff.infrastructure.http;

import com.barbearia.bff.infrastructure.clients.BarbeariaClient;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Rotas do barbearia-service. A autorização (logado para GET, gestor para POST) já foi
 * decidida em RegrasDeAutorizacao antes de chegar aqui; o controller só encaminha, com o sub
 * do token no X-User-ID.
 */
@RestController
@RequestMapping("/barbearias")
public class BarbeariaController {

    private final BarbeariaClient client;

    public BarbeariaController(BarbeariaClient client) {
        this.client = client;
    }

    @GetMapping({"", "/{barbeariaId}/profissionais", "/{barbeariaId}/servicos"})
    public ResponseEntity<String> consultar(HttpServletRequest requisicao, Authentication usuario) {
        return client.encaminhar(requisicao, null, usuario.getName());
    }

    @PostMapping({"", "/{barbeariaId}/profissionais", "/{barbeariaId}/servicos"})
    public ResponseEntity<String> cadastrar(HttpServletRequest requisicao, Authentication usuario,
                                            @RequestBody(required = false) String corpo) {
        return client.encaminhar(requisicao, corpo, usuario.getName());
    }
}
