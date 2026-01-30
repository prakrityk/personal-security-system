from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

def run_migration():
    with engine.connect() as conn:
        print("🚀 Starting Users table migration...")

        # 1. Add firebase_uid as nullable first
        conn.execute(text("""
            ALTER TABLE users 
            ADD COLUMN IF NOT EXISTS firebase_uid VARCHAR(128);
        """))

        # 2. Add the unique index
        conn.execute(text("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_users_firebase_uid 
            ON users(firebase_uid);
        """))

        # 3. Update verification flags for all existing users
        conn.execute(text("""
            UPDATE users 
            SET email_verified = TRUE, 
                phone_verified = TRUE,
                is_active = TRUE
            WHERE email_verified = FALSE OR phone_verified = FALSE OR is_active = FALSE;
        """))

        # 4. Handle existing users by giving them a 'legacy' UID
        # This prevents Step 5 from failing.
        conn.execute(text("""
            UPDATE users 
            SET firebase_uid = 'legacy_' || id::text 
            WHERE firebase_uid IS NULL;
        """))

        # 5. Now that all rows have data, set to NOT NULL
        conn.execute(text("""
            ALTER TABLE users ALTER COLUMN firebase_uid SET NOT NULL;
        """))

        conn.commit()
        print("✅ Users table updated for Firebase successfully")

if __name__ == "__main__":
    try:
        run_migration()
    except Exception as e:
        print(f"❌ Migration failed: {e}")