"""
Database migration: add dependent_safety_settings table

Run:
  python database/migration_add_dependent_safety_settings.py
Rollback:
  python database/migration_add_dependent_safety_settings.py rollback
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
        if _table_exists(engine, "dependent_safety_settings"):
            print("ℹ️  Table 'dependent_safety_settings' already exists - skipping")
            return

        conn.execute(
            text(
                """
                CREATE TABLE dependent_safety_settings (
                    dependent_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                    live_location BOOLEAN NOT NULL DEFAULT FALSE,
                    audio_recording BOOLEAN NOT NULL DEFAULT FALSE,
                    motion_detection BOOLEAN NOT NULL DEFAULT FALSE,
                    auto_recording BOOLEAN NOT NULL DEFAULT FALSE,
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                );
                """
            )
        )

    print("✅ Migration complete: created 'dependent_safety_settings' table")


def rollback():
    engine = _engine()
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS dependent_safety_settings CASCADE;"))
    print("⚠️  Rolled back: dropped 'dependent_safety_settings' table")


if __name__ == "__main__":
    _load_env()
    arg = sys.argv[1].lower() if len(sys.argv) > 1 else ""
    if arg == "rollback":
        rollback()
    else:
        migrate()