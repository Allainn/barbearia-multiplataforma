"""
Dependency injection wiring for FastAPI.

Um único engine SQLAlchemy, compartilhado pela API e pelo consumer Kafka.
"""
import os

from sqlalchemy import create_engine

from disponibilidade.application.use_cases.disponibilidade_use_cases import (
    ConsultarDisponibilidadeUseCase,
    LiberarAgendamentoUseCase,
    RegistrarAgendamentoUseCase,
)
from disponibilidade.infrastructure.database.migrations import run_migrations
from disponibilidade.infrastructure.repositories.postgres_horario_ocupado_repository import (
    PostgresHorarioOcupadoRepository,
)

_repository = None


def get_repository() -> PostgresHorarioOcupadoRepository:
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

    _repository = PostgresHorarioOcupadoRepository(engine)
    return _repository


def get_consultar_disponibilidade_use_case() -> ConsultarDisponibilidadeUseCase:
    return ConsultarDisponibilidadeUseCase(repository=get_repository())


def get_handlers() -> dict:
    """Tópico -> função que aplica o evento ao read model (usado pelo consumer)."""
    repository = get_repository()
    return {
        "agendamento.criado": RegistrarAgendamentoUseCase(repository).execute,
        "agendamento.cancelado": LiberarAgendamentoUseCase(repository).execute,
    }
