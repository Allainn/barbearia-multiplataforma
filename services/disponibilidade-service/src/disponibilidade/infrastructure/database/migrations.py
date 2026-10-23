"""Migrations do disponibilidade-service — cria o read model disponibilidade.horario_ocupado."""

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS disponibilidade.horario_ocupado (
    agendamento_id  UUID        PRIMARY KEY,
    barbearia_id    UUID        NOT NULL,
    profissional_id UUID        NOT NULL,
    inicio          TIMESTAMPTZ NOT NULL,
    fim             TIMESTAMPTZ NOT NULL
);
"""

CREATE_INDEX_SQL = """
CREATE INDEX IF NOT EXISTS horario_ocupado_prof_inicio
    ON disponibilidade.horario_ocupado (profissional_id, inicio);
"""


def run_migrations(engine) -> None:
    from sqlalchemy import text

    with engine.connect() as conn:
        conn.execute(text(CREATE_TABLE_SQL))
        conn.execute(text(CREATE_INDEX_SQL))
        conn.commit()
