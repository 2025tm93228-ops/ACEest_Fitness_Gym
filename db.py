"""SQLite persistence layer, wired into the Flask request lifecycle."""
import os
import sqlite3

from flask import current_app, g

DEFAULT_DB = "aceest_fitness.db"

SCHEMA = """
CREATE TABLE IF NOT EXISTS clients (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    name     TEXT UNIQUE NOT NULL,
    age      INTEGER,
    height   REAL,
    weight   REAL,
    program  TEXT
);

CREATE TABLE IF NOT EXISTS workouts (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    client       TEXT NOT NULL,
    workout_type TEXT NOT NULL,
    duration_min INTEGER NOT NULL,
    notes        TEXT,
    logged_at    TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
"""


def db_path():
    """Resolve the database file: app config first, then env, then default."""
    if current_app:
        return current_app.config.get("DATABASE", DEFAULT_DB)
    return os.environ.get("ACEEST_DB", DEFAULT_DB)


def get_db():
    """Return a per-request SQLite connection with dict-style rows."""
    if "db" not in g:
        g.db = sqlite3.connect(db_path())
        g.db.row_factory = sqlite3.Row
    return g.db


def close_db(exception=None):  # noqa: ARG001 - Flask passes the exception
    """Close the request-scoped connection, if one was opened."""
    conn = g.pop("db", None)
    if conn is not None:
        conn.close()


def init_db():
    """Create tables if they do not already exist."""
    conn = get_db()
    conn.executescript(SCHEMA)
    conn.commit()
