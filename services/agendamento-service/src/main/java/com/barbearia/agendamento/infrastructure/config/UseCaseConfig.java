package com.barbearia.agendamento.infrastructure.config;

import com.barbearia.agendamento.application.commands.CancelarAgendamentoHandler;
import com.barbearia.agendamento.application.commands.CriarAgendamentoHandler;
import com.barbearia.agendamento.application.ports.EventPublisher;
import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;

/** Monta os Command Handlers. */
@Configuration
public class UseCaseConfig {

    @Bean
    public Clock clock() {
        return Clock.systemUTC();
    }

    @Bean
    public CriarAgendamentoHandler criarAgendamentoHandler(
            AgendamentoRepository repository, EventPublisher producer, Clock clock) {
        return new CriarAgendamentoHandler(repository, producer, clock);
    }

    @Bean
    public CancelarAgendamentoHandler cancelarAgendamentoHandler(
            AgendamentoRepository repository, EventPublisher producer, Clock clock) {
        return new CancelarAgendamentoHandler(repository, producer, clock);
    }
}
