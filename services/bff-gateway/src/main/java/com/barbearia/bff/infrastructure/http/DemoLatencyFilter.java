package com.barbearia.bff.infrastructure.http;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/** Injeta latência artificial via header X-Demo-Delay-Ms, igual aos outros serviços. Roda dentro do TelemetryFilter. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
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
