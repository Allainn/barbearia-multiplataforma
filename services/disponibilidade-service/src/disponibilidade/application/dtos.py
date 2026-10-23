from datetime import date, datetime
from uuid import UUID

from pydantic import BaseModel


class HorarioLivreDTO(BaseModel):
    inicio: datetime
    fim: datetime


class DisponibilidadeResponseDTO(BaseModel):
    profissional_id: UUID
    data: date
    horarios_livres: list[HorarioLivreDTO]
