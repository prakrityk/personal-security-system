"""
Database migration: add sos_events table

Run:
  python database/migration_add_sos_events.py
Rollback:
  python database/migration_add_sos_events.py rollback
"""

import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine, text, inspect


def _load_env():
    backend_dir = Path(__file__).resolve().parent.parent
    env_path = backend_dir / ".env"
    load_dotenv(dotenv_path=env_path)
    return backend_dir


def _engine():
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL missing. Create backend/.env with DATABASE_URL.")
    return create_engine(database_url)


def _table_exists(engine, name: str) -> bool:
    inspector = inspect(engine)
    return name in inspector.get_table_names()


def migrate():
    engine = _engine()
    with engine.begin() as conn:
        if _table_exists(engine, "sos_events"):
            print("ℹ️  Table 'sos_events' already exists - skipping")
            return

        conn.execute(
            text(
                """
                CREATE TABLE sos_events (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    trigger_type VARCHAR(32) NOT NULL,
                    event_type VARCHAR(64) NOT NULL,
                    app_state VARCHAR(32),
                    latitude DOUBLE PRECISION,
                    longitude DOUBLE PRECISION,
                    event_timestamp TIMESTAMPTZ,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                );

                CREATE INDEX IF NOT EXISTS ix_sos_events_user_id ON sos_events(user_id);
                CREATE INDEX IF NOT EXISTS ix_sos_events_created_at ON sos_events(created_at);
                """
            )
        )

    print("✅ Migration complete: created 'sos_events' table")


def rollback():
    engine = _engine()
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS sos_events CASCADE;"))
    print("⚠️  Rolled back: dropped 'sos_events' table")


if __name__ == "__main__":
    _load_env()
    arg = sys.argv[1].lower() if len(sys.argv) > 1 else ""
    if arg == "rollback":
        rollback()
    else:
        migrate()

