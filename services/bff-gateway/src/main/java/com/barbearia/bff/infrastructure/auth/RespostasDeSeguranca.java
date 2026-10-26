package com.barbearia.bff.infrastructure.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;

import java.io.IOException;

/**
 * Respostas de 401 e 403 no formato {"detail": "..."} do contrato, em vez do corpo vazio
 * padrão do Spring Security.
 *
 * 401: token ausente, expirado, com assinatura, issuer ou audience errados. Vai com o header
 * WWW-Authenticate: Bearer (RFC 6750 §3); o motivo exato fica no header e no log, não no
 * corpo, para não dar pista a quem está tentando forjar um token.
 *
 * 403: token válido, mas sem a role que a rota exige (ADR-0014).
 */
@Component
public class RespostasDeSeguranca implements AuthenticationEntryPoint, AccessDeniedHandler {

    private static final Logger log = LoggerFactory.getLogger(RespostasDeSeguranca.class);

    @Override
    public void commence(HttpServletRequest request, HttpServletResponse response,
                         AuthenticationException ex) throws IOException {
        StringBuilder desafio = new StringBuilder("Bearer realm=\"barbearia\"");
        if (ex instanceof OAuth2AuthenticationException oauth) {
            OAuth2Error erro = oauth.getError();
            desafio.append(", error=\"").append(erro.getErrorCode()).append('"');
            if (erro.getDescription() != null) {
                desafio.append(", error_description=\"").append(erro.getDescription().replace('"', '\'')).append('"');
            }
            log.warn("401 em {} {}: {}", request.getMethod(), request.getRequestURI(), erro.getDescription());
        } else {
            log.warn("401 em {} {}: sem token", request.getMethod(), request.getRequestURI());
        }
        response.setHeader(HttpHeaders.WWW_AUTHENTICATE, desafio.toString());
        escrever(response, HttpStatus.UNAUTHORIZED, "Token ausente ou inválido");
    }

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException ex) throws IOException {
        log.warn("403 em {} {}: {}", request.getMethod(), request.getRequestURI(), ex.getMessage());
        escrever(response, HttpStatus.FORBIDDEN, "Permissão insuficiente para esta operação");
    }

    private static void escrever(HttpServletResponse response, HttpStatus status, String detail) throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.getWriter().write("{\"detail\": \"" + detail + "\"}");
    }
}
