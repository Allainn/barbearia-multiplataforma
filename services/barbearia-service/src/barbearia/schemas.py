from decimal import Decimal
from uuid import UUID

from pydantic import BaseModel, Field


class BarbeariaIn(BaseModel):
    nome: str = Field(min_length=1, max_length=100)
    endereco: str = Field(min_length=1, max_length=200)


class Barbearia(BarbeariaIn):
    id: UUID


class ProfissionalIn(BaseModel):
    nome: str = Field(min_length=1, max_length=100)


class Profissional(ProfissionalIn):
    id: UUID
    barbearia_id: UUID


class ServicoIn(BaseModel):
    nome: str = Field(min_length=1, max_length=100)
    duracao_min: int = Field(gt=0)
    preco: Decimal = Field(gt=0, max_digits=10, decimal_places=2)


class Servico(ServicoIn):
    id: UUID
    barbearia_id: UUID
