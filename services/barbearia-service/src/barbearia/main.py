import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from .domain.exceptions import BarbeariaNaoEncontrada
from .infrastructure import db
from .infrastructure.http.routes import router
from .infrastructure.migrations import run_migrations
from .infrastructure.telemetry import setup_telemetry


@asynccontextmanager
async def lifespan(_: FastAPI):
    pool = await asyncio.to_thread(db.init_pool)
    with pool.connection() as conn:
        run_migrations(conn)
    yield
    pool.close()


app = FastAPI(
    title="barbearia-service",
    lifespan=lifespan,
    # FastAPI >= 0.142 tem telemetria OTel nativa que pendura mais um exportador
    # OTLP nos providers do telemetry.py, duplicando spans e metricas.
    telemetry={"auto_configure": False},
)


@app.exception_handler(BarbeariaNaoEncontrada)
async def barbearia_nao_encontrada_handler(_: Request, __: BarbeariaNaoEncontrada):
    return JSONResponse(status_code=404, content={"detail": "Barbearia nao encontrada"})


@app.middleware("http")
async def demo_latency_middleware(request: Request, call_next):
    """Latencia artificial via X-Demo-Delay-Ms, para mostrar o pico no Grafana."""
    """Comentário de teste para o GitHub Actions, vendo workflow em execução."""
    try:
        delay_ms = int(request.headers.get("X-Demo-Delay-Ms", "0"))
    except ValueError:
        delay_ms = 0
    if delay_ms > 0:
        await asyncio.sleep(min(delay_ms, 10_000) / 1000)
    return await call_next(request)


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(router)
setup_telemetry(app)
