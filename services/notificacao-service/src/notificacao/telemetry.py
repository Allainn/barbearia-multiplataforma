"""
Configura OpenTelemetry — três pilares: traces, métricas e logs.
Exporta via OTLP HTTP para o OTel Collector (porta 4318).

  Serviço → OTLP HTTP → OTel Collector → Tempo      (traces)
                                        → Prometheus (métricas)
                                        → Loki       (logs)
"""
import logging
import os

from opentelemetry import metrics, trace
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

_LOG = logging.getLogger(__name__)


def setup_telemetry(
    app,
    service_name: str,
    sqlalchemy: bool = False,
    httpx: bool = False,
) -> None:
    """
    Inicializa TracerProvider, MeterProvider e LoggerProvider.
    Instrui o FastAPI e, opcionalmente, httpx.
    """
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4318")

    resource = Resource.create({
        "service.name": service_name,
        "service.version": "1.0.0",
        "service.namespace": "barbearia",
    })

    # ── Traces → OTel Collector → Tempo ────────────────────────────────────
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{endpoint}/v1/traces"))
    )
    trace.set_tracer_provider(tracer_provider)

    # ── Metrics → OTel Collector → Prometheus ──────────────────────────────
    reader = PeriodicExportingMetricReader(
        OTLPMetricExporter(endpoint=f"{endpoint}/v1/metrics"),
        export_interval_millis=15_000,
    )
    meter_provider = MeterProvider(resource=resource, metric_readers=[reader])
    metrics.set_meter_provider(meter_provider)

    # ── Logs → OTel Collector → Loki ───────────────────────────────────────
    logger_provider = LoggerProvider(resource=resource)
    logger_provider.add_log_record_processor(
        BatchLogRecordProcessor(OTLPLogExporter(endpoint=f"{endpoint}/v1/logs"))
    )
    set_logger_provider(logger_provider)

    # Encaminha os registros do logging do Python para o OTel (→ Loki)
    # e injeta traceId/spanId nos atributos do log para correlação
    handler = LoggingHandler(level=logging.NOTSET, logger_provider=logger_provider)
    logging.getLogger().addHandler(handler)
    LoggingInstrumentor().instrument(set_logging_format=True)

    # ── FastAPI → um span por request HTTP ─────────────────────────────────
    FastAPIInstrumentor.instrument_app(app)


    # ── httpx (bff-gateway) ────────────────────────────────────────────────
    if httpx:
        from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
        HTTPXClientInstrumentor().instrument()

    _LOG.info(
        "OpenTelemetry configurado: endpoint=%s service=%s",
        endpoint,
        service_name,
    )
