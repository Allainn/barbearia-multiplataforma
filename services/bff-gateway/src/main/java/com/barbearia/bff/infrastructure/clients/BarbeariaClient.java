package com.barbearia.bff.infrastructure.clients;

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.RetryRegistry;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** barbearia-service: barbearias, profissionais e serviços. */
@Component
public class BarbeariaClient extends ServicoClient {

    public BarbeariaClient(@Value("${bff.servicos.barbearia}") String baseUrl, RestClient restClient,
                           OpenTelemetry openTelemetry, Tracer tracer,
                           CircuitBreakerRegistry circuitBreakers, RetryRegistry retries) {
        super("barbearia-service", baseUrl, restClient, openTelemetry, tracer, circuitBreakers, retries);
    }
}
