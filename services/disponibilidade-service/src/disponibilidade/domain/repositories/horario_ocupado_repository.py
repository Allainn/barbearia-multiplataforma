from abc import ABC, abstractmethod
from datetime import datetime
from uuid import UUID

from disponibilidade.domain.entities.horario_ocupado import HorarioOcupado


class HorarioOcupadoRepository(ABC):

    @abstractmethod
    def registrar(self, horario: HorarioOcupado) -> None:
        """Idempotente: registrar o mesmo agendamento_id duas vezes não muda nada."""

    @abstractmethod
    def remover(self, agendamento_id: UUID) -> None:
        """Idempotente: remover um agendamento que não existe não é erro."""

    @abstractmethod
    def listar_sobrepostos(
        self, profissional_id: UUID, inicio: datetime, fim: datetime
    ) -> list[HorarioOcupado]:
        """Horários do profissional que se sobrepõem a [inicio, fim)."""
