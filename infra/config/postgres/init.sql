-- Barbearia Multiplataforma — isolamento lógico por serviço
-- Uma instância PostgreSQL usa um schema e um usuário para cada serviço.

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS barbearia;
CREATE SCHEMA IF NOT EXISTS agendamento;
CREATE SCHEMA IF NOT EXISTS disponibilidade;
CREATE SCHEMA IF NOT EXISTS notificacao;

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'barbearia_svc') THEN
        CREATE ROLE barbearia_svc LOGIN PASSWORD 'barbearia_pass';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'agendamento_svc') THEN
        CREATE ROLE agendamento_svc LOGIN PASSWORD 'agendamento_pass';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'disponibilidade_svc') THEN
        CREATE ROLE disponibilidade_svc LOGIN PASSWORD 'disponibilidade_pass';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'notificacao_svc') THEN
        CREATE ROLE notificacao_svc LOGIN PASSWORD 'notificacao_pass';
    END IF;
END
$$;

GRANT USAGE, CREATE ON SCHEMA barbearia TO barbearia_svc;
GRANT USAGE, CREATE ON SCHEMA agendamento TO agendamento_svc;
GRANT USAGE, CREATE ON SCHEMA disponibilidade TO disponibilidade_svc;
GRANT USAGE, CREATE ON SCHEMA notificacao TO notificacao_svc;

ALTER DEFAULT PRIVILEGES FOR ROLE barbearia_svc IN SCHEMA barbearia
    GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLES TO barbearia_svc;
ALTER DEFAULT PRIVILEGES FOR ROLE agendamento_svc IN SCHEMA agendamento
    GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLES TO agendamento_svc;
ALTER DEFAULT PRIVILEGES FOR ROLE disponibilidade_svc IN SCHEMA disponibilidade
    GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLES TO disponibilidade_svc;
ALTER DEFAULT PRIVILEGES FOR ROLE notificacao_svc IN SCHEMA notificacao
    GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON TABLES TO notificacao_svc;
