"""
Dependency injection wiring for FastAPI.

Um único engine SQLAlchemy, compartilhado pela API e pelo consumer Kafka.
"""
import os

from sqlalchemy import create_engine

from notificacao.application.use_cases.envio_use_cases import ListarEnviosUseCase
from notificacao.infrastructure.database.migrations import run_migrations
from notificacao.infrastructure.notifiers.log_notifier import LogNotifier
from notificacao.infrastructure.store.postgres_envio_repository import PostgresEnvioRepository

_repository = None
_notifier = None


def get_repository() -> PostgresEnvioRepository:
    global _repository

    if _repository is not None:
        return _repository

    # pool_pre_ping: testa a conexão antes de entregá-la do pool e
    # descarta/reconecta se o Postgres já tiver derrubado ela (restart de
    # container, idle timeout) -- sem isso, o próximo uso falha com
    # "server closed the connection unexpectedly". Importa especialmente
    # aqui: o consumer Kafka usa esse mesmo engine em background.
    engine = create_engine(os.environ["DATABASE_URL"], pool_pre_ping=True, pool_recycle=1800)

    try:
        from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
        SQLAlchemyInstrumentor().instrument(engine=engine)
    except Exception:
        pass

    run_migrations(engine)

    _repository = PostgresEnvioRepository(engine)
    return _repository


def get_notifier() -> LogNotifier:
    global _notifier
    if _notifier is None:
        _notifier = LogNotifier(repository=get_repository())
    return _notifier


def get_listar_envios_use_case() -> ListarEnviosUseCase:
    return ListarEnviosUseCase(repository=get_repository())
