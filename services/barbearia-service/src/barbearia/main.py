import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request

from . import db
from .migrations import run_migrations
from .routes import router
from .telemetry import setup_telemetry


@asynccontextmanager
async def lifespan(_: FastAPI):
    pool = await asyncio.to_thread(db.init_pool)
    with pool.connection() as conn:
        run_migrations(conn)
    yield
    pool.close()


app = FastAPI(title="barbearia-service", lifespan=lifespan)


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


@app.get("/health")
def health():
    return {"status": "ok"}


app.include_router(router)
setup_telemetry(app)
