package com.barbearia.agendamento.infrastructure.http;

import com.barbearia.agendamento.application.commands.AgendamentoNotFoundException;
import com.barbearia.agendamento.domain.exceptions.HorarioIndisponivelException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingRequestHeaderException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.Map;

/** Traduz as exceções para HTTP, sempre no formato {"detail": "..."} do contrato. */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(HorarioIndisponivelException.class)
    public ResponseEntity<Map<String, String>> handleConflict(HorarioIndisponivelException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("detail", ex.getMessage()));
    }

    @ExceptionHandler(AgendamentoNotFoundException.class)
    public ResponseEntity<Map<String, String>> handleNotFound(AgendamentoNotFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("detail", ex.getMessage()));
    }

    @ExceptionHandler(MissingRequestHeaderException.class)
    public ResponseEntity<Map<String, String>> handleMissingHeader(MissingRequestHeaderException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                .body(Map.of("detail", "Header " + ex.getHeaderName() + " ausente."));
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MethodArgumentNotValidException.class,
            MethodArgumentTypeMismatchException.class, IllegalArgumentException.class})
    public ResponseEntity<Map<String, String>> handleValidation(Exception ex) {
        String message = ex instanceof IllegalArgumentException && ex.getMessage() != null
                ? ex.getMessage()
                : "Dados inválidos";
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(Map.of("detail", message));
    }
}
