package com.barbearia.agendamento.application.ports;

import com.barbearia.agendamento.domain.events.DomainEvent;

/**
 * Porta de publicação de eventos. Os Command Handlers dependem só disto; o Kafka
 * concreto fica no adapter infrastructure/kafka/KafkaEventProducer (Clean Architecture,
 * ADR-0010).
 */
@FunctionalInterface
public interface EventPublisher {
    void publish(DomainEvent event);
}
