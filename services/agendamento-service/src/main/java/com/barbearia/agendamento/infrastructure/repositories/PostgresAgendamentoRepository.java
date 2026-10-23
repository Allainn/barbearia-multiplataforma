package com.barbearia.agendamento.infrastructure.repositories;

import com.barbearia.agendamento.domain.entities.Agendamento;
import com.barbearia.agendamento.domain.exceptions.HorarioIndisponivelException;
import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;
import com.barbearia.agendamento.domain.valueobjects.StatusAgendamento;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Repositório PostgreSQL com JdbcTemplate e SQL puro, como no order-service-java do PizzaExpress. */
public class PostgresAgendamentoRepository implements AgendamentoRepository {

    private static final Logger log = LoggerFactory.getLogger(PostgresAgendamentoRepository.class);

    /** SQLState do PostgreSQL para violação de constraint de exclusão. */
    private static final String EXCLUSION_VIOLATION = "23P01";
    /** SQLState do PostgreSQL para deadlock detectado. */
    private static final String DEADLOCK_DETECTED = "40P01";
    private static final int MAX_TENTATIVAS = 3;

    private final JdbcTemplate jdbcTemplate;

    public PostgresAgendamentoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /**
     * Dois INSERTs concorrentes com intervalos sobrepostos podem travar um ao outro na
     * checagem da constraint de exclusão: cada um grava sua entrada no índice e espera a
     * transação do outro. O PostgreSQL aborta um deles com deadlock (40P01) em vez de 23P01.
     * O INSERT abortado é repetido: se o outro confirmou, a repetição cai em 23P01 e vira 409.
     * Cada INSERT roda em autocommit, então repetir não deixa nada pela metade.
     */
    @Override
    public void insert(Agendamento agendamento) {
        for (int tentativa = 1; ; tentativa++) {
            try {
                jdbcTemplate.update("""
                                INSERT INTO agendamento.agendamento
                                    (id, barbearia_id, profissional_id, servico_id, cliente_id, inicio, fim, status)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                                """,
                        agendamento.getId(), agendamento.getBarbeariaId(), agendamento.getProfissionalId(),
                        agendamento.getServicoId(), agendamento.getClienteId(), agendamento.getInicio(),
                        agendamento.getFim(), agendamento.getStatus().name());
                return;
            } catch (DataAccessException e) {
                if (hasSqlState(e, EXCLUSION_VIOLATION)) {
                    throw new HorarioIndisponivelException();
                }
                if (hasSqlState(e, DEADLOCK_DETECTED) && tentativa < MAX_TENTATIVAS) {
                    log.info("Deadlock na constraint de exclusão (agendamento {}), tentativa {} de {}; repetindo o INSERT.",
                            agendamento.getId(), tentativa, MAX_TENTATIVAS);
                    continue;
                }
                throw e;
            }
        }
    }

    @Override
    public void updateStatus(Agendamento agendamento) {
        jdbcTemplate.update("UPDATE agendamento.agendamento SET status = ? WHERE id = ?",
                agendamento.getStatus().name(), agendamento.getId());
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

    private static boolean hasSqlState(Throwable e, String sqlState) {
        for (Throwable cause = e; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLException sql && sqlState.equals(sql.getSQLState())) {
                return true;
            }
        }
        return false;
    }
}
