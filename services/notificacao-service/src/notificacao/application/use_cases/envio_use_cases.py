"""
Use cases da camada de Aplicação — Notificacao Service.

Depende apenas de interfaces de domínio (EnvioRepository),
nunca de implementações concretas de infraestrutura.
"""

from notificacao.application.dtos import EnvioResponseDTO
from notificacao.domain.repositories.envio_repository import EnvioRepository


class ListarEnviosUseCase:
    LIMITE = 20

    def __init__(self, repository: EnvioRepository) -> None:
        self._repository = repository

    def execute(self) -> list[EnvioResponseDTO]:
        return [
            EnvioResponseDTO.model_validate(envio)
            for envio in self._repository.list_recent(self.LIMITE)
        ]
