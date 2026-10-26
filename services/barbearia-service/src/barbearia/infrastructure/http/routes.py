from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends

from barbearia.application.use_cases import (
    CriarBarbearia,
    CriarProfissional,
    CriarServico,
    ListarBarbearias,
    ListarProfissionais,
    ListarServicos,
)
from barbearia.domain.repositories import BarbeariaRepository
from barbearia.infrastructure.db import get_conn
from barbearia.infrastructure.postgres_repository import PostgresBarbeariaRepository

from .schemas import (
    Barbearia,
    BarbeariaIn,
    Profissional,
    ProfissionalIn,
    Servico,
    ServicoIn,
)

router = APIRouter()


def get_repository(
    conn: Annotated[Any, Depends(get_conn, scope="function")],
) -> BarbeariaRepository:
    return PostgresBarbeariaRepository(conn)


# Escopo de funcao: a conexao fecha (e faz o commit) antes de a resposta sair.
Repository = Annotated[BarbeariaRepository, Depends(get_repository, scope="function")]


@router.get("/barbearias", response_model=list[Barbearia])
def listar_barbearias(repository: Repository):
    return ListarBarbearias(repository).executar()


@router.post("/barbearias", response_model=Barbearia, status_code=201)
def criar_barbearia(corpo: BarbeariaIn, repository: Repository):
    return CriarBarbearia(repository).executar(corpo.nome, corpo.endereco)


@router.get("/barbearias/{barbearia_id}/profissionais", response_model=list[Profissional])
def listar_profissionais(barbearia_id: UUID, repository: Repository):
    return ListarProfissionais(repository).executar(barbearia_id)


@router.post(
    "/barbearias/{barbearia_id}/profissionais",
    response_model=Profissional,
    status_code=201,
)
def criar_profissional(
    barbearia_id: UUID, corpo: ProfissionalIn, repository: Repository
):
    return CriarProfissional(repository).executar(barbearia_id, corpo.nome)


@router.get("/barbearias/{barbearia_id}/servicos", response_model=list[Servico])
def listar_servicos(barbearia_id: UUID, repository: Repository):
    return ListarServicos(repository).executar(barbearia_id)


@router.post(
    "/barbearias/{barbearia_id}/servicos", response_model=Servico, status_code=201
)
def criar_servico(barbearia_id: UUID, corpo: ServicoIn, repository: Repository):
    return CriarServico(repository).executar(
        barbearia_id, corpo.nome, corpo.duracao_min, corpo.preco
    )
