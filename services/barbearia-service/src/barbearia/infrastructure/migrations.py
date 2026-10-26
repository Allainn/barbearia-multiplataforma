BARBEARIA_FIXA = (
    "11111111-1111-1111-1111-111111111111",
    "Barbearia Centro",
    "Rua da Bahia 1000",
)
PROFISSIONAL_FIXO = (
    "22222222-2222-2222-2222-222222222222",
    BARBEARIA_FIXA[0],
    "Carlos",
)
SERVICO_FIXO = (
    "33333333-3333-3333-3333-333333333333",
    BARBEARIA_FIXA[0],
    "Corte",
    30,
    "40.00",
)

DDL = [
    """
    CREATE TABLE IF NOT EXISTS barbearia.barbearia (
        id       UUID         PRIMARY KEY,
        nome     VARCHAR(100) NOT NULL,
        endereco VARCHAR(200) NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS barbearia.profissional (
        id           UUID         PRIMARY KEY,
        barbearia_id UUID         NOT NULL REFERENCES barbearia.barbearia(id),
        nome         VARCHAR(100) NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS barbearia.servico (
        id           UUID          PRIMARY KEY,
        barbearia_id UUID          NOT NULL REFERENCES barbearia.barbearia(id),
        nome         VARCHAR(100)  NOT NULL,
        duracao_min  INT           NOT NULL CHECK (duracao_min > 0),
        preco        NUMERIC(10,2) NOT NULL CHECK (preco > 0)
    )
    """,
]


def run_migrations(conn) -> None:
    for stmt in DDL:
        conn.execute(stmt)
    conn.execute(
        "INSERT INTO barbearia.barbearia (id, nome, endereco) VALUES (%s, %s, %s) "
        "ON CONFLICT (id) DO NOTHING",
        BARBEARIA_FIXA,
    )
    conn.execute(
        "INSERT INTO barbearia.profissional (id, barbearia_id, nome) VALUES (%s, %s, %s) "
        "ON CONFLICT (id) DO NOTHING",
        PROFISSIONAL_FIXO,
    )
    conn.execute(
        "INSERT INTO barbearia.servico (id, barbearia_id, nome, duracao_min, preco) "
        "VALUES (%s, %s, %s, %s, %s) ON CONFLICT (id) DO NOTHING",
        SERVICO_FIXO,
    )
