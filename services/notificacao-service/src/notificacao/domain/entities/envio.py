"""
Entidade de domínio: Envio.

Representa o registro imutável de uma notificação enviada ao cliente
em resposta a um evento de agendamento (Kafka). O evento_id garante
que o mesmo evento não gere dois envios.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from uuid import uuid4


@dataclass
class Envio:
    evento_id: str
    tipo: str
    cliente_id: str
    mensagem: str
    payload: dict
    id: str = field(default_factory=lambda: str(uuid4()))
    enviado_em: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
