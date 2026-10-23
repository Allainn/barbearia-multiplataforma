from fastapi import APIRouter, Depends

from notificacao.application.dtos import EnvioResponseDTO
from notificacao.application.use_cases.envio_use_cases import ListarEnviosUseCase
from notificacao.infrastructure.http.dependencies import get_listar_envios_use_case

router = APIRouter(prefix="/notificacoes", tags=["notificacoes"])


@router.get(
    "",
    response_model=list[EnvioResponseDTO],
    summary="Últimos 20 envios (mais recente primeiro)",
)
def listar_notificacoes(
    use_case: ListarEnviosUseCase = Depends(get_listar_envios_use_case),
) -> list[EnvioResponseDTO]:
    return use_case.execute()
