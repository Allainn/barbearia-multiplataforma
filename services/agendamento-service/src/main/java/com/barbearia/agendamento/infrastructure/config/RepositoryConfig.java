package com.barbearia.agendamento.infrastructure.config;

import com.barbearia.agendamento.domain.repositories.AgendamentoRepository;
import com.barbearia.agendamento.infrastructure.database.MigrationRunner;
import com.barbearia.agendamento.infrastructure.kafka.KafkaEventProducer;
import com.barbearia.agendamento.infrastructure.repositories.PostgresAgendamentoRepository;
import com.zaxxer.hikari.HikariDataSource;
import io.opentelemetry.api.OpenTelemetry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * Monta o repositório PostgreSQL (rodando as migrations) e o producer Kafka.
 * Diferente do order-service-java, não existe repositório em memória: sem o banco
 * não há constraint de exclusão, e sem ela não há proteção contra double booking.
 */
@Configuration
public class RepositoryConfig {

    @Value("${SPRING_DATASOURCE_URL:}")
    private String datasourceUrl;

    @Value("${SPRING_DATASOURCE_USERNAME:}")
    private String datasourceUsername;

    @Value("${SPRING_DATASOURCE_PASSWORD:}")
    private String datasourcePassword;

    @Bean(destroyMethod = "close")
    public HikariDataSource dataSource() {
        if (datasourceUrl == null || datasourceUrl.isBlank()) {
            throw new IllegalStateException("SPRING_DATASOURCE_URL não definido: o agendamento-service precisa do PostgreSQL.");
        }
        HikariDataSource dataSource = new HikariDataSource();
        dataSource.setDriverClassName("org.postgresql.Driver");
        dataSource.setJdbcUrl(datasourceUrl);
        dataSource.setUsername(datasourceUsername);
        dataSource.setPassword(datasourcePassword);
        return dataSource;
    }

    @Bean
    public AgendamentoRepository agendamentoRepository(HikariDataSource dataSource) {
        JdbcTemplate jdbcTemplate = new JdbcTemplate(dataSource);
        new MigrationRunner(jdbcTemplate).run();
        return new PostgresAgendamentoRepository(jdbcTemplate);
    }

    @Bean(destroyMethod = "close")
    public KafkaEventProducer kafkaEventProducer(OpenTelemetry openTelemetry) {
        return new KafkaEventProducer(System.getenv("KAFKA_BOOTSTRAP_SERVERS"), openTelemetry);
    }
}
