package com.barbearia.bff.infrastructure.http;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.autoconfigure.security.SecurityProperties;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Injeta latência artificial via header X-Demo-Delay-Ms, igual aos outros serviços. Roda dentro
 * do TelemetryFilter, para o atraso entrar na medição, e DEPOIS do Spring Security: uma
 * requisição sem token recebe 401 na hora, sem prender uma thread por até 5 s.
 */
@Component
@Order(SecurityProperties.DEFAULT_FILTER_ORDER + 1)
public class DemoLatencyFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        int delayMs;
        try {
            delayMs = Integer.parseInt(request.getHeader("X-Demo-Delay-Ms"));
        } catch (NumberFormatException e) {
            delayMs = 0;
        }
        if (delayMs > 0 && delayMs <= 5000) {
            try {
                Thread.sleep(delayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        chain.doFilter(request, response);
    }
}
