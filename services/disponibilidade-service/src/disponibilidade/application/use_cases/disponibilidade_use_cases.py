from datetime import date, datetime, time, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from disponibilidade.domain.entities.horario_ocupado import HorarioOcupado
from disponibilidade.domain.repositories.horario_ocupado_repository import (
    HorarioOcupadoRepository,
)

FUSO = ZoneInfo("America/Sao_Paulo")
ABERTURA = time(9, 0)
FECHAMENTO = time(18, 0)
BLOCO = timedelta(minutes=30)


class RegistrarAgendamentoUseCase:
    """agendamento.criado: marca o intervalo como ocupado."""

    def __init__(self, repository: HorarioOcupadoRepository) -> None:
        self._repository = repository

    def execute(self, evento: dict) -> None:
        payload = evento["payload"]
        self._repository.registrar(
            HorarioOcupado(
                agendamento_id=UUID(payload["agendamento_id"]),
                barbearia_id=UUID(evento["barbearia_id"]),
                profissional_id=UUID(payload["profissional_id"]),
                inicio=datetime.fromisoformat(payload["inicio"]),
                fim=datetime.fromisoformat(payload["fim"]),
            )
        )


class LiberarAgendamentoUseCase:
    """agendamento.cancelado: devolve o intervalo à grade."""

    def __init__(self, repository: HorarioOcupadoRepository) -> None:
        self._repository = repository

    def execute(self, evento: dict) -> None:
        self._repository.remover(UUID(evento["payload"]["agendamento_id"]))


class ConsultarDisponibilidadeUseCase:
    """Grade fixa 09:00–18:00 em blocos de 30 min, menos os blocos ocupados."""

    def __init__(self, repository: HorarioOcupadoRepository) -> None:
        self._repository = repository

    def execute(self, profissional_id: UUID, data: date) -> list[tuple[datetime, datetime]]:
        abertura = datetime.combine(data, ABERTURA, tzinfo=FUSO)
        fechamento = datetime.combine(data, FECHAMENTO, tzinfo=FUSO)
        ocupados = self._repository.listar_sobrepostos(profissional_id, abertura, fechamento)

        livres = []
        inicio = abertura
        while inicio < fechamento:
            fim = inicio + BLOCO
            if not any(o.sobrepoe(inicio, fim) for o in ocupados):
                livres.append((inicio, fim))
            inicio = fim
        return livres
