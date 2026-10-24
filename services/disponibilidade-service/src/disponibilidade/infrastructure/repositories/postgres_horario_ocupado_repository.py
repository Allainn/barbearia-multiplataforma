"""Repositório PostgreSQL do read model — SQLAlchemy Core (sem ORM)."""
from datetime import datetime
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.engine import Engine

from disponibilidade.domain.entities.horario_ocupado import HorarioOcupado
from disponibilidade.domain.repositories.horario_ocupado_repository import (
    HorarioOcupadoRepository,
)


def _parametros(horario: HorarioOcupado) -> dict:
    return {
        "agendamento_id": horario.agendamento_id,
        "barbearia_id": horario.barbearia_id,
        "profissional_id": horario.profissional_id,
        "inicio": horario.inicio,
        "fim": horario.fim,
    }


class PostgresHorarioOcupadoRepository(HorarioOcupadoRepository):

    def __init__(self, engine: Engine) -> None:
        self._engine = engine

    def registrar(self, horario: HorarioOcupado) -> None:
        # DO NOTHING também preserva o tombstone: se o cancelado chegou antes,
        # a linha já existe com cancelado = true e continua assim.
        with self._engine.begin() as conn:
            conn.execute(
                text("""
                    INSERT INTO disponibilidade.horario_ocupado
                        (agendamento_id, barbearia_id, profissional_id, inicio, fim)
                    VALUES
                        (:agendamento_id, :barbearia_id, :profissional_id, :inicio, :fim)
                    ON CONFLICT (agendamento_id) DO NOTHING
                """),
                _parametros(horario),
            )

    def liberar(self, horario: HorarioOcupado) -> None:
        # Grava a linha já cancelada em vez de apagar: se o criado chegar
        # depois, o ON CONFLICT do registrar não a reativa.
        with self._engine.begin() as conn:
            conn.execute(
                text("""
                    INSERT INTO disponibilidade.horario_ocupado
                        (agendamento_id, barbearia_id, profissional_id, inicio, fim, cancelado)
                    VALUES
                        (:agendamento_id, :barbearia_id, :profissional_id, :inicio, :fim, true)
                    ON CONFLICT (agendamento_id) DO UPDATE SET cancelado = true
                """),
                _parametros(horario),
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
                      AND NOT cancelado
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
