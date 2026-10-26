package com.barbearia.bff.infrastructure.config;

import io.github.resilience4j.circuitbreaker.CircuitBreakerConfig;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.RetryConfig;
import io.github.resilience4j.retry.RetryRegistry;
import org.springframework.boot.web.client.ClientHttpRequestFactories;
import org.springframework.boot.web.client.ClientHttpRequestFactorySettings;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import java.time.Duration;

/**
 * HTTP de saída para os serviços: timeouts curtos, circuit breaker por serviço e retry só
 * para GET. Uma requisição de escrita (POST, DELETE) nunca é repetida pelo BFF: se o serviço
 * recebeu e caiu antes de responder, repetir criaria a reserva duas vezes.
 */
@Configuration
public class HttpClientConfig {

    @Bean
    public RestClient restClient(RestClient.Builder builder) {
        ClientHttpRequestFactorySettings settings = ClientHttpRequestFactorySettings.DEFAULTS
                .withConnectTimeout(Duration.ofSeconds(2))
                .withReadTimeout(Duration.ofSeconds(5));
        return builder.requestFactory(ClientHttpRequestFactories.get(settings)).build();
    }

    /**
     * Abre depois de 50% de falha nas últimas 10 chamadas (mínimo de 5), fica aberto 10 s e
     * testa com 2 chamadas. Falha é erro de conexão/timeout ou resposta 5xx; 4xx é resposta
     * válida do serviço e não conta.
     */
    @Bean
    public CircuitBreakerRegistry circuitBreakerRegistry() {
        CircuitBreakerConfig config = CircuitBreakerConfig.custom()
                .slidingWindowSize(10)
                .minimumNumberOfCalls(5)
                .failureRateThreshold(50)
                .waitDurationInOpenState(Duration.ofSeconds(10))
                .permittedNumberOfCallsInHalfOpenState(2)
                .recordExceptions(ResourceAccessException.class)
                .recordResult(r -> r instanceof ResponseEntity<?> resposta && resposta.getStatusCode().is5xxServerError())
                .build();
        return CircuitBreakerRegistry.of(config);
    }

    /** Até 3 tentativas com 200 ms entre elas, só em erro de conexão/timeout ou 5xx. */
    @Bean
    public RetryRegistry retryRegistry() {
        RetryConfig config = RetryConfig.<ResponseEntity<String>>custom()
                .maxAttempts(3)
                .waitDuration(Duration.ofMillis(200))
                .retryExceptions(ResourceAccessException.class)
                .retryOnResult(r -> r.getStatusCode().is5xxServerError())
                .build();
        return RetryRegistry.of(config);
    }
}
