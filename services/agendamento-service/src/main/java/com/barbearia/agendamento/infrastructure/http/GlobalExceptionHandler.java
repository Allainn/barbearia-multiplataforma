package com.barbearia.agendamento.infrastructure.http;

import com.barbearia.agendamento.application.commands.AgendamentoNotFoundException;
import com.barbearia.agendamento.domain.exceptions.AgendamentoDeOutroClienteException;
import com.barbearia.agendamento.domain.exceptions.AgendamentoInvalidoException;
import com.barbearia.agendamento.domain.exceptions.HorarioIndisponivelException;
import io.opentelemetry.api.trace.Span;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.async.AsyncRequestNotUsableException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.Map;

/** Traduz as exceções para HTTP, sempre no formato {"detail": "..."} do contrato. */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);
    private static final String ERRO_INTERNO = "Erro interno no agendamento-service";

    @ExceptionHandler(HorarioIndisponivelException.class)
    public ResponseEntity<Map<String, String>> handleConflict(HorarioIndisponivelException ex) {
        return erro(HttpStatus.CONFLICT, ex.getMessage());
    }

    @ExceptionHandler(AgendamentoNotFoundException.class)
    public ResponseEntity<Map<String, String>> handleNotFound(AgendamentoNotFoundException ex) {
        return erro(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    /**
     * Agendamento de outro cliente recebe a mesma resposta de um inexistente, para o cliente não
     * descobrir ids de reservas alheias. O contrato do DELETE já prevê 204 ou 404. Para responder
     * 403, basta trocar o retorno deste tratador. Só o log diferencia os dois casos.
     */
    @ExceptionHandler(AgendamentoDeOutroClienteException.class)
    public ResponseEntity<Map<String, String>> handleDeOutroCliente(AgendamentoDeOutroClienteException ex) {
        log.warn("Cancelamento recusado com 404. {}", ex.getMessage());
        return handleNotFound(new AgendamentoNotFoundException(ex.getAgendamentoId()));
    }

    @ExceptionHandler(MissingRequestHeaderException.class)
    public ResponseEntity<Map<String, String>> handleMissingHeader(MissingRequestHeaderException ex) {
        return erro(HttpStatus.BAD_REQUEST, "Header " + ex.getHeaderName() + " ausente.");
    }

    /**
     * Só as regras do agendamento viram 422 com a mensagem da exceção. Qualquer outra
     * IllegalArgumentException, como a de um status desconhecido lido do banco, é erro do
     * servidor e cai no 500.
     */
    @ExceptionHandler(AgendamentoInvalidoException.class)
    public ResponseEntity<Map<String, String>> handleInvalido(AgendamentoInvalidoException ex) {
        return erro(HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
    }

    /** Corpo ou caminho que nem chegou ao handler: JSON quebrado, campo faltando, UUID inválido. */
    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentNotValidException.class,
            MethodArgumentTypeMismatchException.class})
    public ResponseEntity<Map<String, String>> handleValidation() {
        return erro(HttpStatus.UNPROCESSABLE_ENTITY, "Dados inválidos");
    }

    /**
     * O cliente desconectou antes da resposta, por um curl cancelado ou pelo timeout do BFF.
     * Não é erro do serviço e não há a quem responder. Sem este tratador, o genérico abaixo
     * registraria um erro com stack trace e tentaria escrever um 500 numa conexão já fechada.
     */
    @ExceptionHandler(AsyncRequestNotUsableException.class)
    public void handleClientGone() {
        // cliente desconectou, não há resposta a enviar
    }

    /**
     * O que sobrou vira o formato do contrato, em vez do {timestamp, status, error, path} padrão
     * do Spring. As exceções do próprio Spring que implementam ErrorResponse mantêm o status e os
     * headers, e só o corpo muda. É o caso da rota inexistente, do 405 com o header Allow e do 415
     * com o header Accept. Todo 5xx vai para o log e para o span do trace, com o tipo e a mensagem
     * da exceção.
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
        log.error("Erro inesperado no agendamento-service", ex);
    }

    private static ResponseEntity<Map<String, String>> erro(HttpStatusCode status, String detail) {
        return erro(status, HttpHeaders.EMPTY, detail);
    }

    /**
     * O Content-Type fixo faz o erro sair em JSON mesmo quando o Accept do cliente não aceita JSON,
     * como no 406. Sem ele, o Spring não acha conversor, desiste do corpo e registra um WARN.
     */
    private static ResponseEntity<Map<String, String>> erro(HttpStatusCode status, HttpHeaders headers,
                                                            String detail) {
        return ResponseEntity.status(status)
                .headers(headers)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("detail", detail));
    }
}
