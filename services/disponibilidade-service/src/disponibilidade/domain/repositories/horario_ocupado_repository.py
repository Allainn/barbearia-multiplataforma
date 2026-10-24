from abc import ABC, abstractmethod
from datetime import datetime
from uuid import UUID

from disponibilidade.domain.entities.horario_ocupado import HorarioOcupado


class HorarioOcupadoRepository(ABC):

    @abstractmethod
    def registrar(self, horario: HorarioOcupado) -> None:
        """Idempotente. Se o agendamento já foi cancelado, a linha continua cancelada."""

    @abstractmethod
    def liberar(self, horario: HorarioOcupado) -> None:
        """Marca o agendamento como cancelado, mesmo que o criado ainda não tenha chegado. Idempotente."""

    @abstractmethod
    def listar_sobrepostos(
        self, profissional_id: UUID, inicio: datetime, fim: datetime
    ) -> list[HorarioOcupado]:
        """Horários do profissional que se sobrepõem a [inicio, fim), sem os cancelados."""
