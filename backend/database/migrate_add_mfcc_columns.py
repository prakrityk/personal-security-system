from sqlalchemy import create_engine, inspect, text
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

def upgrade():
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns('user_voices')]

    if 'mfcc_data' not in columns:
        with engine.connect() as conn:
            # Add column as nullable first
            conn.execute(text('ALTER TABLE user_voices ADD COLUMN mfcc_data BYTEA;'))
            # Optional: fill existing rows with empty bytes
            conn.execute(text("UPDATE user_voices SET mfcc_data = '' WHERE mfcc_data IS NULL;"))
            # Make it NOT NULL after filling
            conn.execute(text("ALTER TABLE user_voices ALTER COLUMN mfcc_data SET NOT NULL;"))
            conn.commit()
        print("✅ Migration applied: mfcc_data column added safely")
    else:
        print("mfcc_data column already exists")

if __name__ == "__main__":
    upgrade()
