package com.barbearia.bff.infrastructure.clients;

import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.RetryRegistry;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Tracer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** agendamento-service: reserva e cancelamento. O X-User-ID vira o cliente_id lá. */
@Component
public class AgendamentoClient extends ServicoClient {

    public AgendamentoClient(@Value("${bff.servicos.agendamento}") String baseUrl, RestClient restClient,
                             OpenTelemetry openTelemetry, Tracer tracer,
                             CircuitBreakerRegistry circuitBreakers, RetryRegistry retries) {
        super("agendamento-service", baseUrl, restClient, openTelemetry, tracer, circuitBreakers, retries);
    }
}
