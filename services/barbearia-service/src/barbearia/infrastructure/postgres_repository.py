from uuid import UUID

from barbearia.domain.entities import Barbearia, Profissional, Servico
from barbearia.domain.repositories import BarbeariaRepository


class PostgresBarbeariaRepository(BarbeariaRepository):
    """Repositorio sobre uma conexao psycopg; quem abre a conexao decide o commit."""

    def __init__(self, conn):
        self._conn = conn

    def listar_barbearias(self) -> list[Barbearia]:
        rows = self._conn.execute(
            "SELECT id, nome, endereco FROM barbearia.barbearia ORDER BY nome"
        ).fetchall()
        return [Barbearia(**row) for row in rows]

    def salvar_barbearia(self, barbearia: Barbearia) -> Barbearia:
        row = self._conn.execute(
            "INSERT INTO barbearia.barbearia (id, nome, endereco) VALUES (%s, %s, %s) "
            "RETURNING id, nome, endereco",
            (barbearia.id, barbearia.nome, barbearia.endereco),
        ).fetchone()
        return Barbearia(**row)

    def existe_barbearia(self, barbearia_id: UUID) -> bool:
        row = self._conn.execute(
            "SELECT 1 FROM barbearia.barbearia WHERE id = %s", (barbearia_id,)
        ).fetchone()
        return row is not None

    def listar_profissionais(self, barbearia_id: UUID) -> list[Profissional]:
        rows = self._conn.execute(
            "SELECT id, barbearia_id, nome FROM barbearia.profissional "
            "WHERE barbearia_id = %s ORDER BY nome",
            (barbearia_id,),
        ).fetchall()
        return [Profissional(**row) for row in rows]

    def salvar_profissional(self, profissional: Profissional) -> Profissional:
        row = self._conn.execute(
            "INSERT INTO barbearia.profissional (id, barbearia_id, nome) "
            "VALUES (%s, %s, %s) RETURNING id, barbearia_id, nome",
            (profissional.id, profissional.barbearia_id, profissional.nome),
        ).fetchone()
        return Profissional(**row)

    def listar_servicos(self, barbearia_id: UUID) -> list[Servico]:
        rows = self._conn.execute(
            "SELECT id, barbearia_id, nome, duracao_min, preco FROM barbearia.servico "
            "WHERE barbearia_id = %s ORDER BY nome",
            (barbearia_id,),
        ).fetchall()
        return [Servico(**row) for row in rows]

    def salvar_servico(self, servico: Servico) -> Servico:
        row = self._conn.execute(
            "INSERT INTO barbearia.servico (id, barbearia_id, nome, duracao_min, preco) "
            "VALUES (%s, %s, %s, %s, %s) "
            "RETURNING id, barbearia_id, nome, duracao_min, preco",
            (
                servico.id,
                servico.barbearia_id,
                servico.nome,
                servico.duracao_min,
                servico.preco,
            ),
        ).fetchone()
        return Servico(**row)
