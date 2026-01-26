from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

with engine.connect() as conn:
    conn.execute(text("""
        ALTER TABLE otps
        ADD COLUMN IF NOT EXISTS attempts INTEGER DEFAULT 0,
        ADD COLUMN IF NOT EXISTS last_sent_at TIMESTAMPTZ
    """))
    conn.commit()

print("✅ OTP columns added successfully")
