"""
Database Migration: Add Collaborator Support
=============================================

This migration adds:
1. guardian_type column to guardian_dependents table
2. collaborator_invitations table for managing collaborator invitations

Run this file directly: python database/migration_add_collaborator_support.py
"""

import os
import sys
from pathlib import Path
from sqlalchemy import create_engine, text, inspect
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print("❌ DATABASE_URL not found in .env file")
    sys.exit(1)

print("=" * 70)
print("🔄 MIGRATION: Add Collaborator Support")
print("=" * 70)
print(f"📊 Database: {DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else 'Unknown'}")
print()


def check_column_exists(engine, table_name, column_name):
    """Check if a column exists in a table"""
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns(table_name)]
    return column_name in columns


def check_table_exists(engine, table_name):
    """Check if a table exists"""
    inspector = inspect(engine)
    return table_name in inspector.get_table_names()


def upgrade():
    """
    Apply the migration:
    - Add guardian_type column to guardian_dependents
    - Create collaborator_invitations table
    """
    print("⬆️  RUNNING UPGRADE...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # ==========================================
            # 1. Add guardian_type column to guardian_dependents
            # ==========================================
            print("📝 Step 1: Adding guardian_type column to guardian_dependents table...")
            
            if check_column_exists(engine, 'guardian_dependents', 'guardian_type'):
                print("   ℹ️  Column 'guardian_type' already exists - skipping")
            else:
                conn.execute(text("""
                    ALTER TABLE guardian_dependents
                    ADD COLUMN guardian_type VARCHAR(20) DEFAULT 'primary' NOT NULL;
                """))
                conn.commit()
                print("   ✅ Added guardian_type column")
            
            print()
            
            # ==========================================
            # 2. Create collaborator_invitations table
            # ==========================================
            print("📝 Step 2: Creating collaborator_invitations table...")
            
            if check_table_exists(engine, 'collaborator_invitations'):
                print("   ℹ️  Table 'collaborator_invitations' already exists - skipping")
            else:
                conn.execute(text("""
                    CREATE TABLE collaborator_invitations (
                        id SERIAL PRIMARY KEY,
                        primary_guardian_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        dependent_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        invitation_code VARCHAR(100) UNIQUE NOT NULL,
                        status VARCHAR(20) DEFAULT 'pending' NOT NULL,
                        collaborator_guardian_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
                        created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
                        expires_at TIMESTAMPTZ NOT NULL,
                        accepted_at TIMESTAMPTZ
                    );
                """))
                conn.commit()
                print("   ✅ Created collaborator_invitations table")
            
            print()
            
            # ==========================================
            # 3. Create indexes for better performance
            # ==========================================
            print("📝 Step 3: Creating indexes...")
            
            try:
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_collab_inv_code 
                    ON collaborator_invitations(invitation_code);
                """))
                
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_collab_inv_status 
                    ON collaborator_invitations(status);
                """))
                
                conn.commit()
                print("   ✅ Created indexes")
            except Exception as e:
                print(f"   ⚠️  Index creation warning: {e}")
            
            print()
            
        print("=" * 70)
        print("✅ MIGRATION SUCCESSFUL!")
        print("=" * 70)
        print()
        print("📊 Summary of changes:")
        print("   1. ✅ Added 'guardian_type' column to guardian_dependents")
        print("   2. ✅ Created 'collaborator_invitations' table")
        print("   3. ✅ Created performance indexes")
        print()
        print("🎯 Next steps:")
        print("   1. Update guardian_dependent.py model to include guardian_type field")
        print("   2. Add collaborator endpoints to api/routes/guardian.py")
        print("   3. Restart your FastAPI server")
        print()
        
    except Exception as e:
        print()
        print("=" * 70)
        print("❌ MIGRATION FAILED!")
        print("=" * 70)
        print(f"Error: {e}")
        print()
        print("💡 Common fixes:")
        print("   - Make sure PostgreSQL is running")
        print("   - Verify DATABASE_URL in .env file")
        print("   - Check that guardian_dependents table exists")
        print("   - Run: psql -U postgres -d safeguard_db")
        print()
        sys.exit(1)


def downgrade():
    """
    Rollback the migration:
    - Remove guardian_type column from guardian_dependents
    - Drop collaborator_invitations table
    """
    print("⬇️  RUNNING DOWNGRADE (ROLLBACK)...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # Drop collaborator_invitations table
            print("📝 Step 1: Dropping collaborator_invitations table...")
            conn.execute(text("DROP TABLE IF EXISTS collaborator_invitations CASCADE;"))
            conn.commit()
            print("   ✅ Dropped table")
            print()
            
            # Remove guardian_type column
            print("📝 Step 2: Removing guardian_type column from guardian_dependents...")
            conn.execute(text("""
                ALTER TABLE guardian_dependents
                DROP COLUMN IF EXISTS guardian_type;
            """))
            conn.commit()
            print("   ✅ Removed column")
            print()
        
        print("=" * 70)
        print("✅ ROLLBACK SUCCESSFUL!")
        print("=" * 70)
        print()
        
    except Exception as e:
        print()
        print("=" * 70)
        print("❌ ROLLBACK FAILED!")
        print("=" * 70)
        print(f"Error: {e}")
        print()
        sys.exit(1)


def verify():
    """Verify the migration was applied correctly"""
    print("🔍 VERIFYING MIGRATION...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        inspector = inspect(engine)
        
        # Check guardian_dependents table
        print("📋 Checking guardian_dependents table:")
        if check_table_exists(engine, 'guardian_dependents'):
            columns = [col['name'] for col in inspector.get_columns('guardian_dependents')]
            print(f"   ✅ Table exists")
            print(f"   📝 Columns: {', '.join(columns)}")
            
            if 'guardian_type' in columns:
                print("   ✅ guardian_type column found")
            else:
                print("   ❌ guardian_type column NOT found!")
        else:
            print("   ❌ Table NOT found!")
        
        print()
        
        # Check collaborator_invitations table
        print("📋 Checking collaborator_invitations table:")
        if check_table_exists(engine, 'collaborator_invitations'):
            columns = [col['name'] for col in inspector.get_columns('collaborator_invitations')]
            print(f"   ✅ Table exists")
            print(f"   📝 Columns: {', '.join(columns)}")
        else:
            print("   ❌ Table NOT found!")
        
        print()
        
    except Exception as e:
        print(f"❌ Verification failed: {e}")
        print()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Database migration for collaborator support")
    parser.add_argument(
        "action",
        choices=["upgrade", "downgrade", "verify"],
        nargs="?",
        default="upgrade",
        help="Migration action: upgrade (default), downgrade, or verify"
    )
    
    args = parser.parse_args()
    
    if args.action == "upgrade":
        upgrade()
        verify()
    elif args.action == "downgrade":
        response = input("⚠️  Are you sure you want to rollback? This will delete data! (yes/no): ")
        if response.lower() == "yes":
            downgrade()
            verify()
        else:
            print("❌ Rollback cancelled")
    elif args.action == "verify":
        verify()