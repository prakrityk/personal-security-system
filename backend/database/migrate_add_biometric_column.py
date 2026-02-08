from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

def run_migration():
    with engine.connect() as conn:
        print("🚀 Starting biometric_enabled column migration...")

        # 1. Add biometric_enabled column with default FALSE
        conn.execute(text("""
            ALTER TABLE users 
            ADD COLUMN IF NOT EXISTS biometric_enabled BOOLEAN DEFAULT FALSE;
        """))
        print("✅ Added biometric_enabled column")

        # 2. Set all existing users to have biometric disabled
        conn.execute(text("""
            UPDATE users 
            SET biometric_enabled = FALSE 
            WHERE biometric_enabled IS NULL;
        """))
        print("✅ Set existing users biometric_enabled to FALSE")

        # 3. Make column NOT NULL after setting defaults
        conn.execute(text("""
            ALTER TABLE users 
            ALTER COLUMN biometric_enabled SET NOT NULL;
        """))
        print("✅ Set biometric_enabled to NOT NULL")

        conn.commit()
        print("✅ Biometric column migration completed successfully")

if __name__ == "__main__":
    try:
        run_migration()
    except Exception as e:
        print(f"❌ Migration failed: {e}")