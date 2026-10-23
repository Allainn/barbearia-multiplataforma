from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends

from disponibilidade.application.dtos import DisponibilidadeResponseDTO, HorarioLivreDTO
from disponibilidade.application.use_cases.disponibilidade_use_cases import (
    ConsultarDisponibilidadeUseCase,
)
from disponibilidade.infrastructure.http.dependencies import (
    get_consultar_disponibilidade_use_case,
)

router = APIRouter(tags=["disponibilidade"])


@router.get(
    "/disponibilidade",
    response_model=DisponibilidadeResponseDTO,
    summary="Horários livres de um profissional em um dia",
)
def consultar_disponibilidade(
    profissional_id: UUID,
    data: date,
    use_case: ConsultarDisponibilidadeUseCase = Depends(get_consultar_disponibilidade_use_case),
) -> DisponibilidadeResponseDTO:
    livres = use_case.execute(profissional_id=profissional_id, data=data)
    return DisponibilidadeResponseDTO(
        profissional_id=profissional_id,
        data=data,
        horarios_livres=[HorarioLivreDTO(inicio=i, fim=f) for i, f in livres],
    )
