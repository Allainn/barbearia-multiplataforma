package com.barbearia.agendamento.infrastructure.database;

import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Cria a tabela do agendamento ao subir. O schema, o usuário e a extensão btree_gist
 * vêm do SQL do contrato (docs/tarefas.md, seção Banco).
 *
 * A constraint sem_sobreposicao é o lock do ADR-0007: o PostgreSQL recusa um segundo
 * agendamento CONFIRMADO do mesmo profissional com intervalo sobreposto, qualquer que
 * seja o número de instâncias do serviço. Os cancelados ficam fora pelo WHERE.
 */
public class MigrationRunner {

    private final JdbcTemplate jdbcTemplate;

    public MigrationRunner(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void run() {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS agendamento.agendamento (
                    id              UUID         PRIMARY KEY,
                    barbearia_id    UUID         NOT NULL,
                    profissional_id UUID         NOT NULL,
                    servico_id      UUID         NOT NULL,
                    cliente_id      VARCHAR(100) NOT NULL,
                    inicio          TIMESTAMPTZ  NOT NULL,
                    fim             TIMESTAMPTZ  NOT NULL,
                    status          VARCHAR(20)  NOT NULL DEFAULT 'CONFIRMADO',
                    criado_em       TIMESTAMPTZ  NOT NULL DEFAULT now(),
                    CHECK (fim > inicio),
                    CONSTRAINT sem_sobreposicao EXCLUDE USING gist (
                        profissional_id WITH =,
                        tstzrange(inicio, fim) WITH &&
                    ) WHERE (status = 'CONFIRMADO')
                )
                """);
    }
}
