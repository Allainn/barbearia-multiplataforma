from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException

from .db import get_conn
from .schemas import (
    Barbearia,
    BarbeariaIn,
    Profissional,
    ProfissionalIn,
    Servico,
    ServicoIn,
)

router = APIRouter()


def _exige_barbearia(conn, barbearia_id: UUID) -> None:
    row = conn.execute(
        "SELECT 1 FROM barbearia.barbearia WHERE id = %s", (barbearia_id,)
    ).fetchone()
    if row is None:
        raise HTTPException(status_code=404, detail="Barbearia nao encontrada")


@router.get("/barbearias", response_model=list[Barbearia])
def listar_barbearias(conn=Depends(get_conn)):
    return conn.execute(
        "SELECT id, nome, endereco FROM barbearia.barbearia ORDER BY nome"
    ).fetchall()


@router.post("/barbearias", response_model=Barbearia, status_code=201)
def criar_barbearia(corpo: BarbeariaIn, conn=Depends(get_conn)):
    row = conn.execute(
        "INSERT INTO barbearia.barbearia (id, nome, endereco) VALUES (%s, %s, %s) "
        "RETURNING id, nome, endereco",
        (uuid4(), corpo.nome, corpo.endereco),
    ).fetchone()
    conn.commit()
    return row


@router.get("/barbearias/{barbearia_id}/profissionais", response_model=list[Profissional])
def listar_profissionais(barbearia_id: UUID, conn=Depends(get_conn)):
    _exige_barbearia(conn, barbearia_id)
    return conn.execute(
        "SELECT id, barbearia_id, nome FROM barbearia.profissional "
        "WHERE barbearia_id = %s ORDER BY nome",
        (barbearia_id,),
    ).fetchall()


@router.post(
    "/barbearias/{barbearia_id}/profissionais",
    response_model=Profissional,
    status_code=201,
)
def criar_profissional(barbearia_id: UUID, corpo: ProfissionalIn, conn=Depends(get_conn)):
    _exige_barbearia(conn, barbearia_id)
    row = conn.execute(
        "INSERT INTO barbearia.profissional (id, barbearia_id, nome) VALUES (%s, %s, %s) "
        "RETURNING id, barbearia_id, nome",
        (uuid4(), barbearia_id, corpo.nome),
    ).fetchone()
    conn.commit()
    return row


@router.get("/barbearias/{barbearia_id}/servicos", response_model=list[Servico])
def listar_servicos(barbearia_id: UUID, conn=Depends(get_conn)):
    _exige_barbearia(conn, barbearia_id)
    return conn.execute(
        "SELECT id, barbearia_id, nome, duracao_min, preco FROM barbearia.servico "
        "WHERE barbearia_id = %s ORDER BY nome",
        (barbearia_id,),
    ).fetchall()


@router.post(
    "/barbearias/{barbearia_id}/servicos", response_model=Servico, status_code=201
)
def criar_servico(barbearia_id: UUID, corpo: ServicoIn, conn=Depends(get_conn)):
    _exige_barbearia(conn, barbearia_id)
    row = conn.execute(
        "INSERT INTO barbearia.servico (id, barbearia_id, nome, duracao_min, preco) "
        "VALUES (%s, %s, %s, %s, %s) "
        "RETURNING id, barbearia_id, nome, duracao_min, preco",
        (uuid4(), barbearia_id, corpo.nome, corpo.duracao_min, corpo.preco),
    ).fetchone()
    conn.commit()
    return row
