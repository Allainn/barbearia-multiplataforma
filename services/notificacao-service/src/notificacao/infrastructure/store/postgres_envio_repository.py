"""Repositório PostgreSQL para Envio — SQLAlchemy Core."""
import json

from sqlalchemy import text
from sqlalchemy.engine import Engine

from notificacao.domain.entities.envio import Envio
from notificacao.domain.repositories.envio_repository import EnvioRepository


class PostgresEnvioRepository(EnvioRepository):
    """Abre uma conexão do pool por operação (a API e o consumer Kafka usam o mesmo engine)."""

    def __init__(self, engine: Engine) -> None:
        self._engine = engine

    def add(self, envio: Envio) -> bool:
        # ON CONFLICT garante a idempotência: a entrega do Kafka é "pelo menos
        # uma vez", então o mesmo evento_id pode chegar mais de uma vez.
        with self._engine.begin() as conn:
            row = conn.execute(
                text("""
                    INSERT INTO notificacao.envio
                        (id, evento_id, tipo, cliente_id, mensagem, payload, enviado_em)
                    VALUES
                        (:id, :evento_id, :tipo, :cliente_id, :mensagem, CAST(:payload AS jsonb), :enviado_em)
                    ON CONFLICT (evento_id) DO NOTHING
                    RETURNING id
                """),
                {
                    "id": envio.id,
                    "evento_id": envio.evento_id,
                    "tipo": envio.tipo,
                    "cliente_id": envio.cliente_id,
                    "mensagem": envio.mensagem,
                    "payload": json.dumps(envio.payload),
                    "enviado_em": envio.enviado_em,
                },
            ).fetchone()
        return row is not None

    def list_recent(self, limit: int) -> list[Envio]:
        with self._engine.connect() as conn:
            rows = conn.execute(
                text("""
                    SELECT id, evento_id, tipo, cliente_id, mensagem, payload, enviado_em
                    FROM notificacao.envio
                    ORDER BY enviado_em DESC
                    LIMIT :limit
                """),
                {"limit": limit},
            ).fetchall()
        return [self._hydrate(r) for r in rows]

    @staticmethod
    def _hydrate(row) -> Envio:
        return Envio(
            id=str(row.id),
            evento_id=str(row.evento_id),
            tipo=row.tipo,
            cliente_id=row.cliente_id,
            mensagem=row.mensagem,
            payload=row.payload if isinstance(row.payload, dict) else json.loads(row.payload),
            enviado_em=row.enviado_em,
        )
