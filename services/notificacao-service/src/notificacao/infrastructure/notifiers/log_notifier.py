"""
LogNotifier — provedor de mensagens simulado.

Monta o texto da notificação a partir do evento de agendamento, grava o
envio (idempotente por evento_id) e "envia" escrevendo no log.
"""

import logging
from datetime import datetime, timedelta, timezone

from notificacao.domain.entities.envio import Envio
from notificacao.domain.repositories.envio_repository import EnvioRepository

logger = logging.getLogger(__name__)

# Horários sempre em America/Sao_Paulo, offset -03:00 (contrato).
_SAO_PAULO = timezone(timedelta(hours=-3))

# Mapeamento de tipo de evento para o texto enviado ao cliente
_TEXTOS: dict[str, str] = {
    "agendamento.criado": "Seu horário de {inicio} está confirmado.",
    "agendamento.cancelado": "Seu horário de {inicio} foi cancelado.",
}


def _formatar_inicio(inicio: str) -> str:
    return datetime.fromisoformat(inicio).astimezone(_SAO_PAULO).strftime("%d/%m %H:%M")


class LogNotifier:
    """Simula o envio de notificações escrevendo no log."""

    def __init__(self, repository: EnvioRepository) -> None:
        self._repository = repository

    def notify(self, tipo: str, evento: dict) -> Envio | None:
        payload = evento["payload"]
        envio = Envio(
            evento_id=evento["evento_id"],
            tipo=tipo,
            cliente_id=payload["cliente_id"],
            mensagem=_TEXTOS[tipo].format(inicio=_formatar_inicio(payload["inicio"])),
            payload=payload,
        )

        # Grava antes de enviar: se o evento_id já existe, o evento é repetido
        # e nada é enviado de novo.
        if not self._repository.add(envio):
            logger.info("evento %s repetido, ignorado", envio.evento_id)
            return None

        logger.info("mensagem enviada para %s: %s", envio.cliente_id, envio.mensagem)
        return envio
