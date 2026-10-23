"""Migrations do notificacao-service — cria a tabela notificacao.envio."""

CREATE_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS notificacao.envio (
    id          UUID         PRIMARY KEY,
    evento_id   UUID         NOT NULL UNIQUE,
    tipo        VARCHAR(50)  NOT NULL,
    cliente_id  VARCHAR(100) NOT NULL,
    mensagem    TEXT         NOT NULL,
    payload     JSONB        NOT NULL,
    enviado_em  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
"""


def run_migrations(engine) -> None:
    from sqlalchemy import text

    with engine.connect() as conn:
        conn.execute(text(CREATE_TABLE_SQL))
        conn.commit()
