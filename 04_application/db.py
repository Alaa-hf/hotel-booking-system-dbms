import os
from pathlib import Path

import psycopg2
from psycopg2 import pool
from dotenv import load_dotenv


env_path = Path(__file__).with_name(".env")
load_dotenv(env_path)

_db_pool = None


def init_pool():
    global _db_pool

    if _db_pool is None:
        required_vars = ["DB_NAME", "DB_USER", "DB_PASSWORD"]
        missing = [var for var in required_vars if not os.getenv(var)]

        if missing:
            raise RuntimeError(f"Missing database environment variables: {', '.join(missing)}")

        _db_pool = pool.SimpleConnectionPool(
            minconn=1,
            maxconn=5,
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
        )

    return _db_pool


def get_connection():
    return init_pool().getconn()


def release_connection(conn):
    if _db_pool and conn:
        _db_pool.putconn(conn)


def close_pool():
    if _db_pool:
        _db_pool.closeall()