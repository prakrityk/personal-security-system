"""
Migration script to add voice_message_url column to sos_events table.
Run this to update existing databases without losing data.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from database.connection import engine
from sqlalchemy import text
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migration_up():
    """Add voice_message_url column to sos_events table"""
    try:
        with engine.connect() as conn:
            # Check if column already exists
            result = conn.execute(
                text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'sos_events' 
                    AND column_name = 'voice_message_url'
                """)
            )
            
            if result.first():
                logger.info("✅ Column 'voice_message_url' already exists in sos_events table")
                return
            
            # Add the column
            conn.execute(
                text("""
                    ALTER TABLE sos_events 
                    ADD COLUMN voice_message_url VARCHAR
                """)
            )
            conn.commit()
            logger.info("✅ Successfully added 'voice_message_url' column to sos_events table")
            
            # Show the updated table structure
            result = conn.execute(
                text("""
                    SELECT column_name, data_type, is_nullable
                    FROM information_schema.columns
                    WHERE table_name = 'sos_events'
                    ORDER BY ordinal_position
                """)
            )
            
            logger.info("📋 Updated sos_events columns:")
            for row in result:
                logger.info(f"   • {row[0]} ({row[1]}, nullable: {row[2]})")
                
    except Exception as e:
        logger.error(f"❌ Migration failed: {e}")
        raise

def migration_down():
    """Remove voice_message_url column (rollback)"""
    try:
        with engine.connect() as conn:
            # Check if column exists
            result = conn.execute(
                text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name = 'sos_events' 
                    AND column_name = 'voice_message_url'
                """)
            )
            
            if not result.first():
                logger.info("Column 'voice_message_url' doesn't exist, nothing to remove")
                return
            
            # Remove the column
            conn.execute(
                text("""
                    ALTER TABLE sos_events 
                    DROP COLUMN voice_message_url
                """)
            )
            conn.commit()
            logger.info("✅ Successfully removed 'voice_message_url' column from sos_events table")
            
    except Exception as e:
        logger.error(f"❌ Rollback failed: {e}")
        raise

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Migrate sos_events table")
    parser.add_argument("--down", action="store_true", help="Rollback the migration")
    args = parser.parse_args()
    
    if args.down:
        migration_down()
    else:
        migration_up()