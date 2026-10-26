from abc import ABC, abstractmethod
from uuid import UUID

from .entities import Barbearia, Profissional, Servico


class BarbeariaRepository(ABC):
    @abstractmethod
    def listar_barbearias(self) -> list[Barbearia]: ...

    @abstractmethod
    def salvar_barbearia(self, barbearia: Barbearia) -> Barbearia: ...

    @abstractmethod
    def existe_barbearia(self, barbearia_id: UUID) -> bool: ...

    @abstractmethod
    def listar_profissionais(self, barbearia_id: UUID) -> list[Profissional]: ...

    @abstractmethod
    def salvar_profissional(self, profissional: Profissional) -> Profissional: ...

    @abstractmethod
    def listar_servicos(self, barbearia_id: UUID) -> list[Servico]: ...

    @abstractmethod
    def salvar_servico(self, servico: Servico) -> Servico: ...
