package com.barbearia.agendamento.infrastructure.repositories;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.barbearia.agendamento.domain.exceptions.AgendamentoInvalidoException;
import com.barbearia.agendamento.domain.exceptions.HorarioIndisponivelException;
import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;
import com.barbearia.agendamento.domain.valueobjects.StatusAgendamento;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/** Repositório PostgreSQL com JdbcTemplate e SQL puro, como no order-service-java do PizzaExpress. */
public class PostgresAgendamentoRepository implements AgendamentoRepository {

    /** SQLState 22001 é texto maior que a coluna, e 22008 é data fora do intervalo do TIMESTAMPTZ. */
    private static final Set<String> VALOR_FORA_DO_LIMITE = Set.of("22001", "22008");

    private final JdbcTemplate jdbcTemplate;

    public PostgresAgendamentoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Quem decide é a constraint sem_sobreposicao (ADR-0007). Sem alvo no ON CONFLICT, o
     * PostgreSQL usa a constraint de exclusão como árbitro: se o intervalo se sobrepõe a um
     * agendamento confirmado, nenhuma linha entra, e isso vira 409.
     *
     * Por que não um INSERT comum tratando o erro 23P01: dois INSERTs sobrepostos ao mesmo
     * tempo gravam cada um sua entrada no índice e esperam a transação do outro, e o PostgreSQL
     * aborta um deles com deadlock (40P01). Com 5 ou mais pedidos simultâneos, os perdedores
     * travavam uns aos outros por vários segundos. Com ON CONFLICT, a inserção é especulativa:
     * quem encontra outra inserção em andamento desfaz a sua e espera o commit da outra, sem deadlock.
     *
     * Um valor do pedido que não cabe na tabela, como um X-User-ID com mais de 100 caracteres ou
     * uma data depois do ano 294276, é erro de quem pediu. Vira AgendamentoInvalidoException e 422,
     * não 500.
     */
    @Override
    public void insert(Agendamento agendamento) {
        int linhas;
        try {
            linhas = jdbcTemplate.update("""
                            INSERT INTO agendamento.agendamento
                                (id, barbearia_id, profissional_id, servico_id, cliente_id, inicio, fim, status)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT DO NOTHING
                            """,
                    agendamento.getId(), agendamento.getBarbeariaId(), agendamento.getProfissionalId(),
                    agendamento.getServicoId(), agendamento.getClienteId(), agendamento.getInicio(),
                    agendamento.getFim(), agendamento.getStatus().name());
        } catch (DataAccessException e) {
            if (e.getMostSpecificCause() instanceof SQLException sql && VALOR_FORA_DO_LIMITE.contains(sql.getSQLState())) {
                throw new AgendamentoInvalidoException("Dados fora dos limites aceitos.");
            }
            throw e;
        }
        if (linhas == 0) {
            throw new HorarioIndisponivelException();
        }
    }

    /**
     * Só grava se o status no banco ainda é outro. Dois DELETEs simultâneos do mesmo
     * agendamento leem CONFIRMADO, mas só um deles muda a linha e publica o evento.
     */
    @Override
    public boolean updateStatus(Agendamento agendamento) {
        String status = agendamento.getStatus().name();
        return jdbcTemplate.update("UPDATE agendamento.agendamento SET status = ? WHERE id = ? AND status <> ?",
                status, agendamento.getId(), status) == 1;
    }

    @Override
    public Optional<Agendamento> findById(UUID id) {
        List<Agendamento> rows = jdbcTemplate.query("""
                        SELECT id, barbearia_id, profissional_id, servico_id, cliente_id, inicio, fim, status
                        FROM agendamento.agendamento WHERE id = ?
                        """,
                this::hydrate, id);
        return rows.stream().findFirst();
    }

    private Agendamento hydrate(ResultSet rs, int rowNum) throws SQLException {
        return Agendamento.reconstruir(
                rs.getObject("id", UUID.class),
                rs.getObject("barbearia_id", UUID.class),
                rs.getObject("profissional_id", UUID.class),
                rs.getObject("servico_id", UUID.class),
                rs.getString("cliente_id"),
                rs.getObject("inicio", OffsetDateTime.class),
                rs.getObject("fim", OffsetDateTime.class),
                StatusAgendamento.valueOf(rs.getString("status")));
    }
}
