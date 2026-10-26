package com.barbearia.bff.infrastructure.http;

import com.barbearia.bff.infrastructure.clients.ServicoIndisponivelException;
import io.opentelemetry.api.trace.Span;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.async.AsyncRequestNotUsableException;

import java.util.Map;

/**
 * Traduz as exceções para HTTP, sempre no formato {"detail": "..."} do contrato. O 401 e o 403
 * não passam por aqui: são respondidos pelo filtro de segurança (RespostasDeSeguranca) antes
 * de qualquer controller.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final String ERRO_INTERNO = "Erro interno no bff-gateway";

    /** Serviço fora do ar, timeout ou circuit breaker aberto. O token já passou: é isso que o 503 prova. */
    @ExceptionHandler(ServicoIndisponivelException.class)
    public ResponseEntity<Map<String, String>> handleIndisponivel(ServicoIndisponivelException ex) {
        Span.current().recordException(ex);
        return erro(HttpStatus.SERVICE_UNAVAILABLE, ex.getServico() + " indisponível");
    }

    /** O cliente desconectou antes da resposta. Não é erro do BFF e não há a quem responder. */
    @ExceptionHandler(AsyncRequestNotUsableException.class)
    public void handleClientGone() {
        // cliente desconectou, não há resposta a enviar
    }

    /**
     * O que sobrou vira o formato do contrato. As exceções do Spring que implementam
     * ErrorResponse (rota inexistente, 405 com Allow, 415) mantêm status e headers; só o corpo
     * muda. Todo 5xx vai para o log e para o span do trace.
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleUnexpected(Exception ex) {
        if (ex instanceof ErrorResponse errorResponse) {
            HttpStatusCode status = errorResponse.getStatusCode();
            if (status.is5xxServerError()) {
                registrarErro(ex);
            }
            String detail = errorResponse.getBody().getDetail();
            if (detail == null) {
                detail = status.is5xxServerError() ? ERRO_INTERNO : "Requisição inválida";
            }
            return erro(status, errorResponse.getHeaders(), detail);
        }
        registrarErro(ex);
        return erro(HttpStatus.INTERNAL_SERVER_ERROR, ERRO_INTERNO);
    }

    private static void registrarErro(Exception ex) {
        Span.current().recordException(ex);
        log.error("Erro inesperado no bff-gateway", ex);
    }

    private static ResponseEntity<Map<String, String>> erro(HttpStatusCode status, String detail) {
        return erro(status, HttpHeaders.EMPTY, detail);
    }

    private static ResponseEntity<Map<String, String>> erro(HttpStatusCode status, HttpHeaders headers,
                                                            String detail) {
        return ResponseEntity.status(status)
                .headers(headers)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("detail", detail));
    }
}
