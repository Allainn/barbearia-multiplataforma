package com.barbearia.bff.infrastructure.config;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.api.metrics.DoubleHistogram;
import io.opentelemetry.api.trace.Tracer;
import io.opentelemetry.api.trace.propagation.W3CTraceContextPropagator;
import io.opentelemetry.context.propagation.ContextPropagators;
import io.opentelemetry.exporter.otlp.http.logs.OtlpHttpLogRecordExporter;
import io.opentelemetry.exporter.otlp.http.metrics.OtlpHttpMetricExporter;
import io.opentelemetry.exporter.otlp.http.trace.OtlpHttpSpanExporter;
import io.opentelemetry.instrumentation.logback.appender.v1_0.OpenTelemetryAppender;
import io.opentelemetry.sdk.OpenTelemetrySdk;
import io.opentelemetry.sdk.logs.SdkLoggerProvider;
import io.opentelemetry.sdk.logs.export.BatchLogRecordProcessor;
import io.opentelemetry.sdk.metrics.SdkMeterProvider;
import io.opentelemetry.sdk.metrics.export.PeriodicMetricReader;
import io.opentelemetry.sdk.resources.Resource;
import io.opentelemetry.sdk.trace.SdkTracerProvider;
import io.opentelemetry.sdk.trace.export.BatchSpanProcessor;
import io.opentelemetry.sdk.trace.samplers.Sampler;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;

/**
 * Três pilares (traces, metrics, logs) via OTLP HTTP pro OTel Collector, igual ao
 * agendamento-service e ao telemetry.py dos serviços Python. SDK configurado manualmente
 * em vez da auto-config do Spring, para os nomes de métrica e atributos serem os mesmos
 * nas duas linguagens e alimentarem os mesmos dashboards.
 */
@Configuration
public class TelemetryConfig {

    private static final String SERVICE_NAME = "bff-gateway";

    @Value("${OTEL_EXPORTER_OTLP_ENDPOINT:http://otel-collector:4318}")
    private String otlpEndpoint;

    @Bean
    public OpenTelemetry openTelemetry() {
        Resource resource = Resource.getDefault().toBuilder()
                .put("service.name", SERVICE_NAME)
                .put("service.namespace", "barbearia")
                .build();

        SdkTracerProvider tracerProvider = SdkTracerProvider.builder()
                .setResource(resource)
                .setSampler(Sampler.alwaysOn())
                .addSpanProcessor(BatchSpanProcessor.builder(
                                OtlpHttpSpanExporter.builder().setEndpoint(otlpEndpoint + "/v1/traces").build())
                        .build())
                .build();

        SdkMeterProvider meterProvider = SdkMeterProvider.builder()
                .setResource(resource)
                .registerMetricReader(PeriodicMetricReader.builder(
                                OtlpHttpMetricExporter.builder().setEndpoint(otlpEndpoint + "/v1/metrics").build())
                        .setInterval(Duration.ofSeconds(15))
                        .build())
                .build();

        SdkLoggerProvider loggerProvider = SdkLoggerProvider.builder()
                .setResource(resource)
                .addLogRecordProcessor(BatchLogRecordProcessor.builder(
                                OtlpHttpLogRecordExporter.builder().setEndpoint(otlpEndpoint + "/v1/logs").build())
                        .build())
                .build();

        OpenTelemetrySdk sdk = OpenTelemetrySdk.builder()
                .setTracerProvider(tracerProvider)
                .setMeterProvider(meterProvider)
                .setLoggerProvider(loggerProvider)
                .setPropagators(ContextPropagators.create(W3CTraceContextPropagator.getInstance()))
                .build();

        // Encaminha os logs do Logback pro OTel (-> Loki).
        OpenTelemetryAppender.install(sdk);

        return sdk;
    }

    @Bean
    public Tracer tracer(OpenTelemetry openTelemetry) {
        return openTelemetry.getTracer(SERVICE_NAME);
    }

    /** Histograma "http.server.duration" (ms), mesmo nome e unidade dos outros serviços. */
    @Bean
    public DoubleHistogram httpServerDuration(OpenTelemetry openTelemetry) {
        return openTelemetry.getMeter(SERVICE_NAME)
                .histogramBuilder("http.server.duration")
                .setUnit("ms")
                .build();
    }
}
