from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID


@dataclass(frozen=True)
class Barbearia:
    id: UUID
    nome: str
    endereco: str


@dataclass(frozen=True)
class Profissional:
    id: UUID
    barbearia_id: UUID
    nome: str


@dataclass(frozen=True)
class Servico:
    id: UUID
    barbearia_id: UUID
    nome: str
    duracao_min: int
    preco: Decimal
