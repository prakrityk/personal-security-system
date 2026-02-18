"""
Database migration: add devices table for FCM tokens

Run:
  python database/migration_add_devices.py
Rollback:
  python database/migration_add_devices.py rollback
"""

import os
import sys

from dotenv import load_dotenv
from sqlalchemy import create_engine, inspect, text


def _engine():
  load_dotenv()
  database_url = os.getenv("DATABASE_URL")
  if not database_url:
      print("❌ DATABASE_URL missing. Check backend/.env.")
      sys.exit(1)
  return create_engine(database_url)


def _table_exists(engine, name: str) -> bool:
  inspector = inspect(engine)
  return name in inspector.get_table_names()


def upgrade():
  engine = _engine()
  with engine.begin() as conn:
      if _table_exists(engine, "devices"):
          print("ℹ️  Table 'devices' already exists - skipping")
          return

      conn.execute(
          text(
              """
              CREATE TABLE devices (
                  id SERIAL PRIMARY KEY,
                  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                  fcm_token VARCHAR(512) NOT NULL UNIQUE,
                  platform VARCHAR(32) NOT NULL DEFAULT 'android',
                  is_active BOOLEAN NOT NULL DEFAULT TRUE,
                  device_info VARCHAR(255),
                  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
              );

              CREATE INDEX IF NOT EXISTS ix_devices_user_id ON devices(user_id);
              CREATE INDEX IF NOT EXISTS ix_devices_is_active ON devices(is_active);
              """
          )
      )

  print("✅ Migration complete: created 'devices' table")


def rollback():
  engine = _engine()
  with engine.begin() as conn:
      conn.execute(text("DROP TABLE IF EXISTS devices CASCADE;"))
  print("⚠️  Rolled back: dropped 'devices' table")


if __name__ == "__main__":
  action = sys.argv[1].lower() if len(sys.argv) > 1 else "upgrade"
  if action == "rollback":
      rollback()
  else:
      upgrade()

