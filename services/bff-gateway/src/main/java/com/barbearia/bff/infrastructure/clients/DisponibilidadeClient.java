package com.barbearia.bff.infrastructure.clients;

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.RetryRegistry;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** disponibilidade-service: horários livres (read model do CQRS, ADR-0008). */
@Component
public class DisponibilidadeClient extends ServicoClient {

    public DisponibilidadeClient(@Value("${bff.servicos.disponibilidade}") String baseUrl, RestClient restClient,
                                 OpenTelemetry openTelemetry, Tracer tracer,
                                 CircuitBreakerRegistry circuitBreakers, RetryRegistry retries) {
        super("disponibilidade-service", baseUrl, restClient, openTelemetry, tracer, circuitBreakers, retries);
    }
}
