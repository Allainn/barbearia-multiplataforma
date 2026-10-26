package com.barbearia.bff.infrastructure.http;

import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Scope;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Instrumentação HTTP manual (1 span SERVER + 1 registro em http.server.duration por request),
 * igual ao agendamento-service, para alimentar os mesmos dashboards.
 *
 * Roda ANTES do filtro do Spring Security (ordem -100): assim os 401 e 403 também entram no
 * trace e na métrica, o que é parte do que a plataforma precisa mostrar. O DemoLatencyFilter
 * vem logo depois, para o atraso ficar dentro da medição.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class TelemetryFilter extends OncePerRequestFilter {

    private final Tracer tracer;
    private final DoubleHistogram httpServerDuration;

    public TelemetryFilter(Tracer tracer, DoubleHistogram httpServerDuration) {
        this.tracer = tracer;
        this.httpServerDuration = httpServerDuration;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long startNanos = System.nanoTime();
        Span span = tracer.spanBuilder(request.getMethod() + " " + request.getRequestURI())
                .setSpanKind(SpanKind.SERVER)
                .setAttribute("http.method", request.getMethod())
                .setAttribute("http.target", request.getRequestURI())
                .setAttribute("http.scheme", request.getScheme())
                .startSpan();
        try (Scope scope = span.makeCurrent()) {
            chain.doFilter(request, response);
        } finally {
            long elapsedMs = (System.nanoTime() - startNanos) / 1_000_000;
            int status = response.getStatus();
            span.setAttribute("http.status_code", status);
            if (status >= 500) {
                span.setStatus(StatusCode.ERROR);
            }
            span.end();

            httpServerDuration.record(elapsedMs, Attributes.builder()
                    .put("http.method", request.getMethod())
                    .put("http.target", request.getRequestURI())
                    .put("http.status_code", String.valueOf(status))
                    .build());
        }
    }
}
