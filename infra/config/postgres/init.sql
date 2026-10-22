-- PizzaExpress — Inicialização dos schemas por serviço
-- Cada microserviço tem seu schema isolado no mesmo banco

CREATE SCHEMA IF NOT EXISTS catalog;
CREATE SCHEMA IF NOT EXISTS orders;
CREATE SCHEMA IF NOT EXISTS delivery;
CREATE SCHEMA IF NOT EXISTS notifications;

-- Usuários por serviço (isolamento de acesso)
CREATE USER catalog_svc WITH PASSWORD 'catalog_pass';
CREATE USER order_svc WITH PASSWORD 'order_pass';
CREATE USER delivery_svc WITH PASSWORD 'delivery_pass';
CREATE USER notification_svc WITH PASSWORD 'notification_pass';

GRANT USAGE, CREATE ON SCHEMA catalog TO catalog_svc;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA catalog TO catalog_svc;
ALTER DEFAULT PRIVILEGES IN SCHEMA catalog GRANT ALL ON TABLES TO catalog_svc;

GRANT USAGE, CREATE ON SCHEMA orders TO order_svc;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA orders TO order_svc;
ALTER DEFAULT PRIVILEGES IN SCHEMA orders GRANT ALL ON TABLES TO order_svc;

GRANT USAGE, CREATE ON SCHEMA delivery TO delivery_svc;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA delivery TO delivery_svc;
ALTER DEFAULT PRIVILEGES IN SCHEMA delivery GRANT ALL ON TABLES TO delivery_svc;

GRANT USAGE, CREATE ON SCHEMA notifications TO notification_svc;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA notifications TO notification_svc;
ALTER DEFAULT PRIVILEGES IN SCHEMA notifications GRANT ALL ON TABLES TO notification_svc;
