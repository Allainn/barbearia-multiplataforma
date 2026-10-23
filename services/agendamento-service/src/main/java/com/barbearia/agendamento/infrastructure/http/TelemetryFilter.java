package com.barbearia.agendamento.infrastructure.http;

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
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * Instrumentação HTTP manual (1 span + 1 registro na métrica http.server.duration
 * por request) -- par funcional do FastAPIInstrumentor automático do Python
 * (telemetry.py). Nomes de métrica/atributos seguem a mesma convenção semântica
 * OTel usada lá, pra alimentar os MESMOS dashboards Grafana (ex.: disponibilidade.json)
 * com dados dos dois lados, Python e Java.
 */
@Component
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
