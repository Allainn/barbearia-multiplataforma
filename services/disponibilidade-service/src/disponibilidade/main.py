import asyncio
import logging

from fastapi import FastAPI, Request

from disponibilidade.infrastructure.http.router import router
from disponibilidade.infrastructure.http.dependencies import get_handlers
from disponibilidade.infrastructure.kafka.consumer import start_event_consumer
from disponibilidade.telemetry import setup_telemetry

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s — %(message)s",
)

app = FastAPI(
    title="Barbearia — Disponibilidade Service",
    version="1.0.0",
    description=(
        "Lado de leitura do CQRS: consome os eventos de agendamento do Kafka "
        "e responde quais horários do profissional estão livres."
    ),
    # FastAPI >= 0.142 tem telemetria OTel nativa que, no startup, pendura
    # MAIS um exportador OTLP (lido de OTEL_EXPORTER_OTLP_ENDPOINT) nos providers
    # que telemetry.py já configurou -- sem deduplicar. Resultado: logs, spans e
    # métricas saindo em dobro.
    telemetry={"auto_configure": False},
)


@app.middleware("http")
async def demo_latency_middleware(request: Request, call_next):
    """Injeta latência artificial via header X-Demo-Delay-Ms (uso exclusivo em demos/aulas)."""
    try:
        delay_ms = int(request.headers.get("x-demo-delay-ms", "0"))
    except ValueError:
        delay_ms = 0
    if 0 < delay_ms <= 5000:
        await asyncio.sleep(delay_ms / 1000)
    return await call_next(request)


app.include_router(router)
setup_telemetry(app, service_name="disponibilidade-service")

start_event_consumer(get_handlers())


@app.get("/health", tags=["health"])
def health() -> dict:
    return {"status": "ok", "service": "disponibilidade-service"}
