from decimal import Decimal
from uuid import UUID, uuid4

from barbearia.domain.entities import Barbearia, Profissional, Servico
from barbearia.domain.exceptions import BarbeariaNaoEncontrada
from barbearia.domain.repositories import BarbeariaRepository


class ListarBarbearias:
    def __init__(self, repository: BarbeariaRepository):
        self._repository = repository

    def executar(self) -> list[Barbearia]:
        return self._repository.listar_barbearias()


class CriarBarbearia:
    def __init__(self, repository: BarbeariaRepository):
        self._repository = repository

    def executar(self, nome: str, endereco: str) -> Barbearia:
        barbearia = Barbearia(id=uuid4(), nome=nome, endereco=endereco)
        return self._repository.salvar_barbearia(barbearia)


class _UseCaseDeBarbearia:
    def __init__(self, repository: BarbeariaRepository):
        self._repository = repository

    def _exige_barbearia(self, barbearia_id: UUID) -> None:
        if not self._repository.existe_barbearia(barbearia_id):
            raise BarbeariaNaoEncontrada(str(barbearia_id))


class ListarProfissionais(_UseCaseDeBarbearia):
    def executar(self, barbearia_id: UUID) -> list[Profissional]:
        self._exige_barbearia(barbearia_id)
        return self._repository.listar_profissionais(barbearia_id)


class CriarProfissional(_UseCaseDeBarbearia):
    def executar(self, barbearia_id: UUID, nome: str) -> Profissional:
        self._exige_barbearia(barbearia_id)
        profissional = Profissional(id=uuid4(), barbearia_id=barbearia_id, nome=nome)
        return self._repository.salvar_profissional(profissional)


class ListarServicos(_UseCaseDeBarbearia):
    def executar(self, barbearia_id: UUID) -> list[Servico]:
        self._exige_barbearia(barbearia_id)
        return self._repository.listar_servicos(barbearia_id)


class CriarServico(_UseCaseDeBarbearia):
    def executar(
        self, barbearia_id: UUID, nome: str, duracao_min: int, preco: Decimal
    ) -> Servico:
        self._exige_barbearia(barbearia_id)
        servico = Servico(
            id=uuid4(),
            barbearia_id=barbearia_id,
            nome=nome,
            duracao_min=duracao_min,
            preco=preco,
        )
        return self._repository.salvar_servico(servico)
