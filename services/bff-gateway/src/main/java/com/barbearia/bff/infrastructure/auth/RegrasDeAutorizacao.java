package com.barbearia.bff.infrastructure.auth;

import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AuthorizeHttpRequestsConfigurer;

/**
 * Matriz de autorização do ADR-0014, num só lugar e declarativa (ADR-0015). A regra por
 * papel é decidida aqui, antes do controller; a regra por recurso (dono do agendamento)
 * fica no serviço que guarda o dado.
 *
 * Negar por padrão: uma rota nova que não esteja listada aqui é recusada, mesmo autenticada.
 * Adicionar uma rota ao BFF é acrescentar a linha dela nesta matriz.
 */
final class RegrasDeAutorizacao {

    static final String ROLE_CLIENTE = "cliente";
    static final String ROLE_GESTOR = "gestor";

    private RegrasDeAutorizacao() {
    }

    static void aplicar(AuthorizeHttpRequestsConfigurer<HttpSecurity>.AuthorizationManagerRequestMatcherRegistry rotas) {
        rotas
                .requestMatchers("/health").permitAll()
                // Consultas: qualquer usuário autenticado ("logado").
                .requestMatchers(HttpMethod.GET, "/barbearias/**").authenticated()
                .requestMatchers(HttpMethod.GET, "/disponibilidade").authenticated()
                // Cadastro da barbearia, dos profissionais e dos serviços: gestor.
                .requestMatchers(HttpMethod.POST, "/barbearias/**").hasRole(ROLE_GESTOR)
                // Reserva e cancelamento: cliente.
                .requestMatchers(HttpMethod.POST, "/agendamentos").hasRole(ROLE_CLIENTE)
                .requestMatchers(HttpMethod.DELETE, "/agendamentos/*").hasRole(ROLE_CLIENTE)
                .anyRequest().denyAll();
    }
}
