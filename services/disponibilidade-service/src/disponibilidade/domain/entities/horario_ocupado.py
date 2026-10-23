from dataclasses import dataclass
from datetime import datetime
from uuid import UUID


@dataclass(frozen=True)
class HorarioOcupado:
    """Linha do read model: intervalo em que o profissional já tem agendamento."""

    agendamento_id: UUID
    barbearia_id: UUID
    profissional_id: UUID
    inicio: datetime
    fim: datetime

    def sobrepoe(self, inicio: datetime, fim: datetime) -> bool:
        return self.inicio < fim and self.fim > inicio
