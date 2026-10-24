import asyncio
import logging

from fastapi import FastAPI, Request

from notificacao.infrastructure.http.router import router
from notificacao.infrastructure.http.dependencies import get_notifier
from notificacao.infrastructure.kafka.consumer import start_event_consumer
from notificacao.telemetry import setup_telemetry

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)

app = FastAPI(
    title="Barbearia — Notificacao Service",
    version="1.0.0",
    description=(
        "Consome os eventos de agendamento do Kafka e envia a notificacao "
        "ao cliente (provedor simulado, grava no log)."
    ),
    # FastAPI >= 0.142 tem telemetria OTel nativa que, no startup, pendura
    # MAIS um exportador OTLP (lido de OTEL_EXPORTER_OTLP_ENDPOINT) nos providers
    # que telemetry.py já configurou -- sem deduplicar. Resultado: logs, spans e
    # métricas saindo em dobro.
    telemetry={"auto_configure": False},
)


@app.middleware("http")
async def demo_latency_middleware(request: Request, call_next):
    """Latencia artificial via X-Demo-Delay-Ms, para mostrar o pico no Grafana."""
    try:
        delay_ms = int(request.headers.get("X-Demo-Delay-Ms", "0"))
    except ValueError:
        delay_ms = 0
    if delay_ms > 0:
        await asyncio.sleep(min(delay_ms, 10_000) / 1000)
    return await call_next(request)


app.include_router(router)
setup_telemetry(app, service_name="notificacao-service")

notifier = get_notifier()
start_event_consumer(notifier)


@app.get("/health", tags=["health"])
def health() -> dict:
    return {"status": "ok", "service": "notificacao-service"}
