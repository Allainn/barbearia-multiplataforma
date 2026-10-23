package com.barbearia.agendamento.infrastructure.kafka;

import com.barbearia.agendamento.application.ports.EventPublisher;
import com.barbearia.agendamento.domain.events.DomainEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.SpanKind;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.context.Context;
import io.opentelemetry.context.Scope;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.Producer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Properties;
import java.util.UUID;

/**
 * Publica os eventos do agendamento no Kafka (ADR-0006). O tópico é o nome do evento
 * (agendamento.criado ou agendamento.cancelado) e a chave é o profissional_id, para
 * todos os eventos de um profissional caírem na mesma partição e chegarem em ordem.
 *
 * Adaptado do order-service-java do PizzaExpress: sem KAFKA_BOOTSTRAP_SERVERS opera em
 * modo "dry-run" (só loga) e injeta o contexto de trace W3C nos headers da mensagem.
 */
public class KafkaEventProducer implements EventPublisher {

    private static final Logger log = LoggerFactory.getLogger(KafkaEventProducer.class);

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final Producer<String, String> producer;
    private final OpenTelemetry openTelemetry;
    private final Tracer tracer;

    public KafkaEventProducer(String bootstrapServers, OpenTelemetry openTelemetry) {
        this.producer = buildProducer(bootstrapServers);
        this.openTelemetry = openTelemetry;
        this.tracer = openTelemetry.getTracer("agendamento-service.kafka");
    }

    private static Producer<String, String> buildProducer(String bootstrapServers) {
        if (bootstrapServers == null || bootstrapServers.isBlank()) {
            log.info("KAFKA_BOOTSTRAP_SERVERS not set -- Kafka producer in dry-run mode.");
            return null;
        }
        try {
            Properties props = new Properties();
            props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
            props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
            props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
            // Com o Kafka fora do ar, a reserva espera no máximo alguns segundos em vez dos 60 s padrão.
            props.put(ProducerConfig.MAX_BLOCK_MS_CONFIG, 5000);
            props.put(ProducerConfig.REQUEST_TIMEOUT_MS_CONFIG, 5000);
            props.put(ProducerConfig.DELIVERY_TIMEOUT_MS_CONFIG, 10000);
            Producer<String, String> producer = new KafkaProducer<>(props);
            log.info("Kafka producer connected to {}", bootstrapServers);
            return producer;
        } catch (Exception e) {
            log.warn("Could not connect to Kafka ({}) -- running in dry-run mode: {}", bootstrapServers, e.getMessage());
            return null;
        }
    }

    /**
     * Falha ao publicar só vai para o log: a reserva já está gravada e não é desfeita.
     * Sem Outbox (ADR-0012), esse evento fica perdido.
     */
    @Override
    public void publish(DomainEvent event) {
        String topic = event.eventName();
        String key = event.profissionalId().toString();
        Map<String, Object> envelope = buildEnvelope(event);

        if (producer == null) {
            log.info("[DRY-RUN] Would publish to topic '{}' with key '{}': {}", topic, key, envelope);
            return;
        }

        Span span = tracer.spanBuilder("kafka publish " + topic)
                .setSpanKind(SpanKind.PRODUCER)
                .setAttribute("messaging.system", "kafka")
                .setAttribute("messaging.destination", topic)
                .setAttribute("messaging.destination_kind", "topic")
                .setAttribute("messaging.operation", "publish")
                .startSpan();
        try (Scope scope = span.makeCurrent()) {
            String json = objectMapper.writeValueAsString(envelope);
            ProducerRecord<String, String> record = new ProducerRecord<>(topic, key, json);

            openTelemetry.getPropagators().getTextMapPropagator().inject(
                    Context.current(), record,
                    (carrier, k, value) -> carrier.headers().add(k, value.getBytes(StandardCharsets.UTF_8)));

            producer.send(record).get();
            log.info("Published event '{}' (agendamento {}) to topic '{}'", topic, event.agendamentoId(), topic);
        } catch (Exception e) {
            log.error("Failed to publish event '{}' (agendamento {}): {}", topic, event.agendamentoId(), e.getMessage());
        } finally {
            span.end();
        }
    }

    public void close() {
        if (producer != null) {
            producer.close();
        }
    }

    /** Envelope do contrato: evento_id, tipo, versao, ocorrido_em, barbearia_id e payload. */
    Map<String, Object> buildEnvelope(DomainEvent event) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("agendamento_id", event.agendamentoId().toString());
        payload.put("profissional_id", event.profissionalId().toString());
        payload.put("cliente_id", event.clienteId());
        payload.put("inicio", event.inicio().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME));
        payload.put("fim", event.fim().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME));

        Map<String, Object> envelope = new LinkedHashMap<>();
        envelope.put("evento_id", UUID.randomUUID().toString());
        envelope.put("tipo", event.eventName());
        envelope.put("versao", 1);
        envelope.put("ocorrido_em", DateTimeFormatter.ISO_INSTANT.format(event.ocorridoEm()));
        envelope.put("barbearia_id", event.barbeariaId().toString());
        envelope.put("payload", payload);
        return envelope;
    }
}
