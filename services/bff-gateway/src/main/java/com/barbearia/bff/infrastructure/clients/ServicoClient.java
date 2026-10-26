package com.barbearia.bff.infrastructure.clients;

import io.github.resilience4j.circuitbreaker.CallNotPermittedException;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.github.resilience4j.retry.Retry;
import io.github.resilience4j.retry.RetryRegistry;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.StatusCode;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Context;
import io.opentelemetry.context.Scope;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StreamUtils;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClient;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.function.Supplier;

/**
 * Encaminha a requisição para um serviço: mesmo método, caminho, query string e corpo, mais o
 * header X-User-ID com o sub do token (ADR-0015). Devolve o status e o corpo do serviço como
 * vieram (201, 204, 404, 409, 422...), para o BFF não reinterpretar o contrato de cada serviço.
 * O header Authorization NÃO é repassado: a fronteira de confiança é o BFF.
 *
 * Cada chamada ganha um span CLIENT e leva o traceparent, para o trace continuar no serviço.
 */
public abstract class ServicoClient {

    private static final Logger log = LoggerFactory.getLogger(ServicoClient.class);
    static final String HEADER_USUARIO = "X-User-ID";

    private final String nome;
    private final String baseUrl;
    private final RestClient restClient;
    private final OpenTelemetry openTelemetry;
    private final Tracer tracer;
    private final CircuitBreaker circuitBreaker;
    private final Retry retry;

    protected ServicoClient(String nome, String baseUrl, RestClient restClient, OpenTelemetry openTelemetry,
                            Tracer tracer, CircuitBreakerRegistry circuitBreakers, RetryRegistry retries) {
        this.nome = nome;
        this.baseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        this.restClient = restClient;
        this.openTelemetry = openTelemetry;
        this.tracer = tracer;
        this.circuitBreaker = circuitBreakers.circuitBreaker(nome);
        this.retry = retries.retry(nome);
    }

    public ResponseEntity<String> encaminhar(HttpServletRequest requisicao, String corpo, String usuarioId) {
        HttpMethod metodo = HttpMethod.valueOf(requisicao.getMethod());
        String query = requisicao.getQueryString();
        String uri = baseUrl + requisicao.getRequestURI() + (query == null ? "" : "?" + query);
        String contentType = requisicao.getContentType();

        Supplier<ResponseEntity<String>> chamada = () -> executar(metodo, uri, corpo, contentType, usuarioId);
        Supplier<ResponseEntity<String>> protegida = CircuitBreaker.decorateSupplier(circuitBreaker, chamada);
        if (metodo == HttpMethod.GET) {
            // Retry só em leitura: repetir uma escrita poderia duplicar a reserva.
            protegida = Retry.decorateSupplier(retry, protegida);
        }
        try {
            return protegida.get();
        } catch (CallNotPermittedException e) {
            log.warn("Circuit breaker de {} aberto; {} {} recusado sem chamar o serviço", nome, metodo, uri);
            throw new ServicoIndisponivelException(nome, "circuit breaker aberto", e);
        } catch (ResourceAccessException e) {
            log.warn("{} não respondeu em {} {}: {}", nome, metodo, uri, e.getMessage());
            throw new ServicoIndisponivelException(nome, e.getMessage(), e);
        }
    }

    private ResponseEntity<String> executar(HttpMethod metodo, String uri, String corpo, String contentType,
                                            String usuarioId) {
        Span span = tracer.spanBuilder(metodo + " " + nome)
                .setSpanKind(SpanKind.CLIENT)
                .setAttribute("http.method", metodo.name())
                .setAttribute("http.url", uri)
                .setAttribute("peer.service", nome)
                .startSpan();
        try (Scope scope = span.makeCurrent()) {
            // URI.create: a string já vem codificada do request; uri(String) a trataria como
            // template e codificaria de novo (%20 viraria %2520).
            RestClient.RequestBodySpec spec = restClient.method(metodo)
                    .uri(URI.create(uri))
                    .accept(MediaType.APPLICATION_JSON)
                    .header(HEADER_USUARIO, usuarioId);
            openTelemetry.getPropagators().getTextMapPropagator()
                    .inject(Context.current(), spec, (carrier, chave, valor) -> carrier.header(chave, valor));
            if (corpo != null && !corpo.isEmpty()) {
                spec.contentType(contentType != null ? MediaType.parseMediaType(contentType) : MediaType.APPLICATION_JSON)
                        .body(corpo);
            }
            ResponseEntity<String> resposta = spec.exchange((pedido, retorno) -> {
                String conteudo = StreamUtils.copyToString(retorno.getBody(), StandardCharsets.UTF_8);
                ResponseEntity.BodyBuilder builder = ResponseEntity.status(retorno.getStatusCode());
                if (conteudo.isEmpty()) {
                    return builder.build();
                }
                return builder.contentType(MediaType.APPLICATION_JSON).body(conteudo);
            });
            span.setAttribute("http.status_code", resposta.getStatusCode().value());
            if (resposta.getStatusCode().is5xxServerError()) {
                span.setStatus(StatusCode.ERROR);
            }
            return resposta;
        } catch (RuntimeException e) {
            span.recordException(e);
            span.setStatus(StatusCode.ERROR);
            throw e;
        } finally {
            span.end();
        }
    }
}
