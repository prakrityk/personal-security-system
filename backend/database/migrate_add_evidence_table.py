"""
Migration script to add evidence table
Run this after updating models/__init__.py and user.py

This creates the backend PostgreSQL table for evidence storage.
NOTE: Flutter app has its OWN local SQLite evidence table (in-device).
This backend table just stores metadata about uploaded evidence.

The 'id' column here is what Flutter stores as 'server_id' when it gets
the response back from POST /api/evidence/create
"""
from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

def run_migration():
    with engine.connect() as conn:
        print("🚀 Creating evidence table...")

        # Create evidence table
        # id = auto-generated primary key (what Flutter stores as server_id after creation)
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS evidence (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                evidence_type VARCHAR(50) NOT NULL,
                local_path VARCHAR(500) NOT NULL,
                file_url VARCHAR(500),
                upload_status VARCHAR(50) NOT NULL DEFAULT 'pending',
                file_size INTEGER,
                duration INTEGER,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                uploaded_at TIMESTAMPTZ
            );
        """))
        print("✅ Created evidence table")

        # Create index on user_id for faster queries
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_evidence_user_id ON evidence(user_id);
        """))
        print("✅ Created index on user_id")

        # Create index on upload_status for pending uploads query
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_evidence_upload_status ON evidence(upload_status);
        """))
        print("✅ Created index on upload_status")

        conn.commit()
        print("✅ Evidence table migration completed successfully")

if __name__ == "__main__":
    try:
        run_migration()
    except Exception as e:
        print(f"❌ Migration failed: {e}")