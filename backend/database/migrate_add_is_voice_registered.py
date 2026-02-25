from sqlalchemy import create_engine, inspect, text
import os
from dotenv import load_dotenv

load_dotenv()

engine = create_engine(os.getenv("DATABASE_URL"))

def upgrade():
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns('users')]

    if 'is_voice_registered' not in columns:
        with engine.connect() as conn:
            conn.execute(text("""
                ALTER TABLE users
                ADD COLUMN is_voice_registered BOOLEAN DEFAULT FALSE NOT NULL;
            """))
            conn.commit()
        print("✅ Migration applied: is_voice_registered added")
    else:
        print("ℹ️ Column already exists")

if __name__ == "__main__":
    upgrade()
