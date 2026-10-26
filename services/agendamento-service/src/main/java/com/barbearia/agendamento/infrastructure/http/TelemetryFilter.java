package com.barbearia.agendamento.infrastructure.http;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.common.Attributes;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Context;
import io.opentelemetry.context.Scope;
import io.opentelemetry.context.propagation.TextMapGetter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;

/**
 * Instrumentação HTTP manual (1 span + 1 registro na métrica http.server.duration
 * por request) -- par funcional do FastAPIInstrumentor automático do Python
 * (telemetry.py). Nomes de métrica/atributos seguem a mesma convenção semântica
 * OTel usada lá, pra alimentar os MESMOS dashboards Grafana (ex.: disponibilidade.json)
 * com dados dos dois lados, Python e Java.
 *
 * Roda antes do DemoLatencyFilter, para o atraso do X-Demo-Delay-Ms ficar dentro do span e do
 * http.server.duration e aparecer no Grafana. Sem o @Order, os dois filtros tinham a mesma
 * prioridade e o DemoLatencyFilter rodava primeiro, fora da medição.
 *
 * O span SERVER continua o trace de quem chamou: o BFF manda o traceparent, e o contexto dele vira
 * o pai do span. Sem isso, o trace do POST /agendamentos se partia em dois, um terminando no BFF e
 * outro começando aqui e seguindo pelo Kafka. O FastAPIInstrumentor dos serviços Python já faz a
 * mesma extração sozinho.
 */
@Component
@Order(Ordered.LOWEST_PRECEDENCE - 1)
public class TelemetryFilter extends OncePerRequestFilter {

    /** Lê os headers da requisição para o propagador W3C encontrar o traceparent. */
    private static final TextMapGetter<HttpServletRequest> HEADERS = new TextMapGetter<>() {
        @Override
        public Iterable<String> keys(HttpServletRequest request) {
            return Collections.list(request.getHeaderNames());
        }

        @Override
        public String get(HttpServletRequest request, String chave) {
            return request == null ? null : request.getHeader(chave);
        }
    };

    private final OpenTelemetry openTelemetry;
    private final Tracer tracer;
    private final DoubleHistogram httpServerDuration;

    public TelemetryFilter(OpenTelemetry openTelemetry, Tracer tracer, DoubleHistogram httpServerDuration) {
        this.openTelemetry = openTelemetry;
        this.tracer = tracer;
        this.httpServerDuration = httpServerDuration;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        long startNanos = System.nanoTime();
        Context pai = openTelemetry.getPropagators().getTextMapPropagator()
                .extract(Context.current(), request, HEADERS);
        Span span = tracer.spanBuilder(request.getMethod() + " " + request.getRequestURI())
                .setParent(pai)
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
