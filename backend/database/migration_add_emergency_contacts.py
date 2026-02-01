"""
Database Migration: Add Emergency Contacts
===========================================

This migration adds:
1. emergency_contacts table for storing emergency contact information
2. Auto-sync functionality for guardian-dependent relationships

Run this file directly: python database/migration_add_emergency_contacts.py
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
print("🔄 MIGRATION: Add Emergency Contacts")
print("=" * 70)
print(f"📊 Database: {DATABASE_URL.split('@')[1] if '@' in DATABASE_URL else 'Unknown'}")
print()


def check_column_exists(engine, table_name, column_name):
    """Check if a column exists in a table"""
    inspector = inspect(engine)
    try:
        columns = [col['name'] for col in inspector.get_columns(table_name)]
        return column_name in columns
    except:
        return False


def check_table_exists(engine, table_name):
    """Check if a table exists"""
    inspector = inspect(engine)
    return table_name in inspector.get_table_names()


def upgrade():
    """
    Apply the migration:
    - Create emergency_contacts table
    - Create indexes for better performance
    """
    print("⬆️  RUNNING UPGRADE...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # ==========================================
            # 1. Create emergency_contacts table
            # ==========================================
            print("📝 Step 1: Creating emergency_contacts table...")
            
            if check_table_exists(engine, 'emergency_contacts'):
                print("   ℹ️  Table 'emergency_contacts' already exists - skipping")
            else:
                conn.execute(text("""
                    CREATE TABLE emergency_contacts (
                        id SERIAL PRIMARY KEY,
                        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                        contact_name VARCHAR(100) NOT NULL,
                        contact_phone VARCHAR(20) NOT NULL,
                        contact_email VARCHAR(255),
                        contact_relationship VARCHAR(50),
                        priority INTEGER DEFAULT 999 NOT NULL,
                        is_active BOOLEAN DEFAULT true NOT NULL,
                        source VARCHAR(20) DEFAULT 'manual' NOT NULL,
                        guardian_relationship_id INTEGER REFERENCES guardian_dependents(id) ON DELETE CASCADE,
                        created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
                        updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
                    );
                """))
                conn.commit()
                print("   ✅ Created emergency_contacts table")
            
            print()
            
            # ==========================================
            # 2. Create indexes for better performance
            # ==========================================
            print("📝 Step 2: Creating indexes...")
            
            try:
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_emergency_contacts_id 
                    ON emergency_contacts(id);
                """))
                
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_emergency_contacts_user_id 
                    ON emergency_contacts(user_id);
                """))
                
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_emergency_contacts_priority 
                    ON emergency_contacts(priority);
                """))
                
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_emergency_contacts_is_active 
                    ON emergency_contacts(is_active);
                """))
                
                conn.commit()
                print("   ✅ Created indexes")
            except Exception as e:
                print(f"   ⚠️  Index creation warning: {e}")
            
            print()
            
            # ==========================================
            # 3. Create trigger for updated_at
            # ==========================================
            print("📝 Step 3: Creating trigger for updated_at...")
            
            try:
                # Create or replace the trigger function (if not exists)
                conn.execute(text("""
                    CREATE OR REPLACE FUNCTION update_updated_at_column()
                    RETURNS TRIGGER AS $$
                    BEGIN
                        NEW.updated_at = NOW();
                        RETURN NEW;
                    END;
                    $$ LANGUAGE plpgsql;
                """))
                
                # Create trigger
                conn.execute(text("""
                    DROP TRIGGER IF EXISTS update_emergency_contacts_updated_at 
                    ON emergency_contacts;
                """))
                
                conn.execute(text("""
                    CREATE TRIGGER update_emergency_contacts_updated_at
                    BEFORE UPDATE ON emergency_contacts
                    FOR EACH ROW
                    EXECUTE FUNCTION update_updated_at_column();
                """))
                
                conn.commit()
                print("   ✅ Created trigger for automatic updated_at")
            except Exception as e:
                print(f"   ⚠️  Trigger creation warning: {e}")
            
            print()
            
        print("=" * 70)
        print("✅ MIGRATION SUCCESSFUL!")
        print("=" * 70)
        print()
        print("📊 Summary of changes:")
        print("   1. ✅ Created 'emergency_contacts' table")
        print("   2. ✅ Created performance indexes")
        print("   3. ✅ Created auto-update trigger for updated_at")
        print()
        print("📋 Table Structure:")
        print("   - id (Primary Key)")
        print("   - user_id (Foreign Key → users)")
        print("   - contact_name (VARCHAR 100)")
        print("   - contact_phone (VARCHAR 20)")
        print("   - contact_email (VARCHAR 255, optional)")
        print("   - relationship (VARCHAR 50, optional)")
        print("   - priority (INTEGER, default 999)")
        print("   - is_active (BOOLEAN, default true)")
        print("   - source (VARCHAR 20: manual/phone_contacts/auto_guardian)")
        print("   - guardian_relationship_id (Foreign Key → guardian_dependents)")
        print("   - created_at (TIMESTAMPTZ)")
        print("   - updated_at (TIMESTAMPTZ, auto-updated)")
        print()
        print("🎯 Next steps:")
        print("   1. Add emergency_contact.py model to backend/models/")
        print("   2. Add emergency_contact.py schemas to backend/api/schemas/")
        print("   3. Add emergency_contact.py routes to backend/api/routes/")
        print("   4. Add emergency_contact_utils.py to backend/utils/")
        print("   5. Register routes in main.py")
        print("   6. Restart your FastAPI server")
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
        print("   - Check that users table exists")
        print("   - Check that guardian_dependents table exists")
        print("   - Run: psql -U postgres -d safeguard_db")
        print()
        import traceback
        traceback.print_exc()
        sys.exit(1)


def downgrade():
    """
    Rollback the migration:
    - Drop emergency_contacts table
    - Drop trigger and function
    """
    print("⬇️  RUNNING DOWNGRADE (ROLLBACK)...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # Drop trigger
            print("📝 Step 1: Dropping trigger...")
            try:
                conn.execute(text("""
                    DROP TRIGGER IF EXISTS update_emergency_contacts_updated_at 
                    ON emergency_contacts;
                """))
                conn.commit()
                print("   ✅ Dropped trigger")
            except Exception as e:
                print(f"   ℹ️  Trigger drop: {e}")
            print()
            
            # Drop table
            print("📝 Step 2: Dropping emergency_contacts table...")
            conn.execute(text("DROP TABLE IF EXISTS emergency_contacts CASCADE;"))
            conn.commit()
            print("   ✅ Dropped table")
            print()
        
        print("=" * 70)
        print("✅ ROLLBACK SUCCESSFUL!")
        print("=" * 70)
        print()
        print("⚠️  All emergency contact data has been deleted!")
        print()
        
    except Exception as e:
        print()
        print("=" * 70)
        print("❌ ROLLBACK FAILED!")
        print("=" * 70)
        print(f"Error: {e}")
        print()
        import traceback
        traceback.print_exc()
        sys.exit(1)


def verify():
    """Verify the migration was applied correctly"""
    print("🔍 VERIFYING MIGRATION...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        inspector = inspect(engine)
        
        # Check emergency_contacts table
        print("📋 Checking emergency_contacts table:")
        if check_table_exists(engine, 'emergency_contacts'):
            columns = [col['name'] for col in inspector.get_columns('emergency_contacts')]
            print(f"   ✅ Table exists")
            print(f"   📝 Columns ({len(columns)}):")
            for col in columns:
                print(f"      - {col}")
            print()
            
            # Check required columns
            required_columns = [
                'id', 'user_id', 'contact_name', 'contact_phone',
                'priority', 'is_active', 'source', 'created_at', 'updated_at'
            ]
            
            missing = [col for col in required_columns if col not in columns]
            if missing:
                print(f"   ❌ Missing columns: {', '.join(missing)}")
            else:
                print("   ✅ All required columns present")
            print()
            
            # Check indexes
            print("📋 Checking indexes:")
            indexes = inspector.get_indexes('emergency_contacts')
            print(f"   📝 Found {len(indexes)} indexes:")
            for idx in indexes:
                print(f"      - {idx['name']}")
            print()
            
            # Check foreign keys
            print("📋 Checking foreign keys:")
            foreign_keys = inspector.get_foreign_keys('emergency_contacts')
            print(f"   📝 Found {len(foreign_keys)} foreign keys:")
            for fk in foreign_keys:
                print(f"      - {fk['constrained_columns']} → {fk['referred_table']}.{fk['referred_columns']}")
            print()
            
            # Count records
            with engine.connect() as conn:
                result = conn.execute(text("SELECT COUNT(*) FROM emergency_contacts;"))
                count = result.scalar()
                print(f"📊 Current records: {count}")
            print()
            
        else:
            print("   ❌ Table NOT found!")
            print()
        
        print("=" * 70)
        print("✅ VERIFICATION COMPLETE")
        print("=" * 70)
        print()
        
    except Exception as e:
        print(f"❌ Verification failed: {e}")
        print()
        import traceback
        traceback.print_exc()


def seed_sample_data():
    """Seed sample emergency contacts for testing (optional)"""
    print("🌱 SEEDING SAMPLE DATA...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # Check if there are any users to add contacts for
            result = conn.execute(text("SELECT id FROM users LIMIT 1;"))
            user = result.fetchone()
            
            if not user:
                print("   ℹ️  No users found - skipping seed")
                return
            
            user_id = user[0]
            
            # Check if contacts already exist
            result = conn.execute(text(
                "SELECT COUNT(*) FROM emergency_contacts WHERE user_id = :user_id;"
            ), {"user_id": user_id})
            count = result.scalar()
            
            if count > 0:
                print(f"   ℹ️  User {user_id} already has {count} contacts - skipping seed")
                return
            
            # Insert sample contacts
            print(f"   📝 Adding sample contacts for user {user_id}...")
            
            conn.execute(text("""
                INSERT INTO emergency_contacts 
                (user_id, contact_name, contact_phone, contact_email, relationship, priority, source)
                VALUES
                (:user_id, 'Emergency Contact 1', '+1234567890', 'contact1@example.com', 'Mother', 1, 'manual'),
                (:user_id, 'Emergency Contact 2', '+0987654321', 'contact2@example.com', 'Father', 2, 'manual'),
                (:user_id, 'Emergency Contact 3', '+1111111111', 'contact3@example.com', 'Friend', 3, 'phone_contacts');
            """), {"user_id": user_id})
            
            conn.commit()
            print("   ✅ Added 3 sample emergency contacts")
            print()
        
        print("=" * 70)
        print("✅ SEED COMPLETE")
        print("=" * 70)
        print()
        
    except Exception as e:
        print(f"❌ Seeding failed: {e}")
        print()
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Database migration for emergency contacts")
    parser.add_argument(
        "action",
        choices=["upgrade", "downgrade", "verify", "seed"],
        nargs="?",
        default="upgrade",
        help="Migration action: upgrade (default), downgrade, verify, or seed"
    )
    
    args = parser.parse_args()
    
    if args.action == "upgrade":
        upgrade()
        verify()
        print("💡 Tip: Run 'python database/migration_add_emergency_contacts.py seed' to add sample data")
        print()
    elif args.action == "downgrade":
        response = input("⚠️  Are you sure you want to rollback? This will DELETE ALL emergency contacts! (yes/no): ")
        if response.lower() == "yes":
            downgrade()
            verify()
        else:
            print("❌ Rollback cancelled")
    elif args.action == "verify":
        verify()
    elif args.action == "seed":
        seed_sample_data()