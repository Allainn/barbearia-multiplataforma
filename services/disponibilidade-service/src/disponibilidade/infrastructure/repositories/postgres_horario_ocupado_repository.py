"""Repositório PostgreSQL do read model — SQLAlchemy Core (sem ORM)."""
from datetime import datetime
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.engine import Engine

from disponibilidade.domain.entities.horario_ocupado import HorarioOcupado
from disponibilidade.domain.repositories.horario_ocupado_repository import (
    HorarioOcupadoRepository,
)


class PostgresHorarioOcupadoRepository(HorarioOcupadoRepository):

    def __init__(self, engine: Engine) -> None:
        self._engine = engine

    def registrar(self, horario: HorarioOcupado) -> None:
        with self._engine.begin() as conn:
            conn.execute(
                text("""
                    INSERT INTO disponibilidade.horario_ocupado
                        (agendamento_id, barbearia_id, profissional_id, inicio, fim)
                    VALUES
                        (:agendamento_id, :barbearia_id, :profissional_id, :inicio, :fim)
                    ON CONFLICT (agendamento_id) DO NOTHING
                """),
                {
                    "agendamento_id": horario.agendamento_id,
                    "barbearia_id": horario.barbearia_id,
                    "profissional_id": horario.profissional_id,
                    "inicio": horario.inicio,
                    "fim": horario.fim,
                },
            )

    def remover(self, agendamento_id: UUID) -> None:
        with self._engine.begin() as conn:
            conn.execute(
                text("DELETE FROM disponibilidade.horario_ocupado WHERE agendamento_id = :id"),
                {"id": agendamento_id},
            )

    def listar_sobrepostos(
        self, profissional_id: UUID, inicio: datetime, fim: datetime
    ) -> list[HorarioOcupado]:
        with self._engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT agendamento_id, barbearia_id, profissional_id, inicio, fim
                    FROM disponibilidade.horario_ocupado
                    WHERE profissional_id = :profissional_id
                      AND inicio < :fim AND fim > :inicio
                    ORDER BY inicio
                """),
                {"profissional_id": profissional_id, "inicio": inicio, "fim": fim},
            ).fetchall()
        return [
            HorarioOcupado(
                agendamento_id=UUID(str(r.agendamento_id)),
                barbearia_id=UUID(str(r.barbearia_id)),
                profissional_id=UUID(str(r.profissional_id)),
                inicio=r.inicio,
                fim=r.fim,
            )
            for r in rows
        ]
