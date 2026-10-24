import os
import time

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

pool: ConnectionPool | None = None


def init_pool() -> ConnectionPool:
    """Abre o pool, tentando de novo enquanto o Postgres ainda sobe."""
    global pool
    pool = ConnectionPool(
        os.environ["DATABASE_URL"],
        min_size=1,
        max_size=5,
        open=False,
        kwargs={"row_factory": dict_row},
    )
    for tentativa in range(30):
        try:
            pool.open(wait=True, timeout=5)
            return pool
        except Exception:
            if tentativa == 29:
                raise
            time.sleep(2)
    return pool


def get_conn():
    assert pool is not None
    with pool.connection() as conn:
        yield conn
