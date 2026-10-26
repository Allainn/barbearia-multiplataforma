package com.barbearia.bff.infrastructure.clients;

/** O serviço de destino não respondeu (conexão, timeout) ou o circuit breaker dele está aberto. Vira 503. */
public class ServicoIndisponivelException extends RuntimeException {

    private final String servico;

    public ServicoIndisponivelException(String servico, String motivo, Throwable causa) {
        super(servico + " indisponível: " + motivo, causa);
        this.servico = servico;
    }

    public String getServico() {
        return servico;
    }
}
