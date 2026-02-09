"""
Database Migration: Add Auto-Guardian Tracking to Emergency Contacts
=====================================================================

This migration adds fields to track auto-generated guardian emergency contacts:
1. is_auto_generated - Flag to mark auto-created contacts
2. auto_from_guardian_id - Track which guardian created the contact
3. phone_number - Alias for contact_phone (for consistency)
4. relationship - Alias for contact_relationship (for consistency)

Run this file directly: python migration_fix_emergency_contacts_guardian.py
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
print("🔄 MIGRATION: Add Auto-Guardian Tracking to Emergency Contacts")
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
    - Add is_auto_generated column
    - Add auto_from_guardian_id column
    - Rename contact_phone to phone_number (add alias)
    - Rename contact_relationship to relationship (add alias)
    """
    print("⬆️  RUNNING UPGRADE...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # ==========================================
            # 1. Add is_auto_generated column
            # ==========================================
            print("📝 Step 1: Adding is_auto_generated column...")
            
            if check_column_exists(engine, 'emergency_contacts', 'is_auto_generated'):
                print("   ℹ️  Column 'is_auto_generated' already exists - skipping")
            else:
                conn.execute(text("""
                    ALTER TABLE emergency_contacts
                    ADD COLUMN is_auto_generated BOOLEAN DEFAULT FALSE NOT NULL;
                """))
                conn.commit()
                print("   ✅ Added is_auto_generated column")
            
            print()
            
            # ==========================================
            # 2. Add auto_from_guardian_id column
            # ==========================================
            print("📝 Step 2: Adding auto_from_guardian_id column...")
            
            if check_column_exists(engine, 'emergency_contacts', 'auto_from_guardian_id'):
                print("   ℹ️  Column 'auto_from_guardian_id' already exists - skipping")
            else:
                conn.execute(text("""
                    ALTER TABLE emergency_contacts
                    ADD COLUMN auto_from_guardian_id INTEGER REFERENCES users(id) ON DELETE CASCADE;
                """))
                conn.commit()
                print("   ✅ Added auto_from_guardian_id column")
            
            print()
            
            # ==========================================
            # 3. Rename contact_phone to phone_number (if needed)
            # ==========================================
            print("📝 Step 3: Checking phone number column naming...")
            
            has_contact_phone = check_column_exists(engine, 'emergency_contacts', 'contact_phone')
            has_phone_number = check_column_exists(engine, 'emergency_contacts', 'phone_number')
            
            if has_contact_phone and not has_phone_number:
                print("   🔄 Renaming contact_phone to phone_number...")
                conn.execute(text("""
                    ALTER TABLE emergency_contacts
                    RENAME COLUMN contact_phone TO phone_number;
                """))
                conn.commit()
                print("   ✅ Renamed contact_phone → phone_number")
            elif has_phone_number:
                print("   ℹ️  Column 'phone_number' already exists - skipping")
            else:
                print("   ⚠️  Neither contact_phone nor phone_number found - table may need creation")
            
            print()
            
            # ==========================================
            # 4. Rename contact_relationship to relationship (if needed)
            # ==========================================
            print("📝 Step 4: Checking relationship column naming...")
            
            has_contact_relationship = check_column_exists(engine, 'emergency_contacts', 'contact_relationship')
            has_relationship = check_column_exists(engine, 'emergency_contacts', 'relationship')
            
            if has_contact_relationship and not has_relationship:
                print("   🔄 Renaming contact_relationship to relationship...")
                conn.execute(text("""
                    ALTER TABLE emergency_contacts
                    RENAME COLUMN contact_relationship TO relationship;
                """))
                conn.commit()
                print("   ✅ Renamed contact_relationship → relationship")
            elif has_relationship:
                print("   ℹ️  Column 'relationship' already exists - skipping")
            else:
                print("   ⚠️  Neither contact_relationship nor relationship found - table may need creation")
            
            print()
            
            # ==========================================
            # 5. Create indexes for new columns
            # ==========================================
            print("📝 Step 5: Creating indexes for new columns...")
            
            try:
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_emergency_contacts_is_auto_generated 
                    ON emergency_contacts(is_auto_generated);
                """))
                
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS ix_emergency_contacts_auto_from_guardian_id 
                    ON emergency_contacts(auto_from_guardian_id);
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
        print("   1. ✅ Added 'is_auto_generated' column (BOOLEAN)")
        print("   2. ✅ Added 'auto_from_guardian_id' column (FK → users)")
        print("   3. ✅ Renamed 'contact_phone' → 'phone_number' (if needed)")
        print("   4. ✅ Renamed 'contact_relationship' → 'relationship' (if needed)")
        print("   5. ✅ Created performance indexes")
        print()
        print("🎯 Next steps:")
        print("   1. ✅ Update models/emergency_contact.py (use phone_number, relationship)")
        print("   2. ✅ Update api/routes/guardian_auto_contacts.py (already uses correct fields)")
        print("   3. ✅ Update api/schemas/pending_dependent.py (add guardian_type)")
        print("   4. ✅ Restart your FastAPI server")
        print()
        print("💡 Testing:")
        print("   - Create a QR code and scan it (primary guardian)")
        print("   - Check dependent's emergency contacts")
        print("   - Add a collaborator guardian")
        print("   - Verify both primary and collaborator appear in contacts")
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
        print("   - Check that emergency_contacts table exists")
        print("   - Run: python migration_add_emergency_contacts.py first")
        print()
        import traceback
        traceback.print_exc()
        sys.exit(1)


def downgrade():
    """
    Rollback the migration:
    - Remove is_auto_generated column
    - Remove auto_from_guardian_id column
    - Rename phone_number back to contact_phone
    - Rename relationship back to contact_relationship
    """
    print("⬇️  RUNNING DOWNGRADE (ROLLBACK)...")
    print()
    
    try:
        engine = create_engine(DATABASE_URL)
        
        with engine.connect() as conn:
            # Drop indexes
            print("📝 Step 1: Dropping indexes...")
            try:
                conn.execute(text("""
                    DROP INDEX IF EXISTS ix_emergency_contacts_is_auto_generated;
                """))
                conn.execute(text("""
                    DROP INDEX IF EXISTS ix_emergency_contacts_auto_from_guardian_id;
                """))
                conn.commit()
                print("   ✅ Dropped indexes")
            except Exception as e:
                print(f"   ℹ️  Index drop: {e}")
            print()
            
            # Rename columns back
            print("📝 Step 2: Renaming columns back...")
            try:
                if check_column_exists(engine, 'emergency_contacts', 'phone_number'):
                    conn.execute(text("""
                        ALTER TABLE emergency_contacts
                        RENAME COLUMN phone_number TO contact_phone;
                    """))
                    print("   ✅ Renamed phone_number → contact_phone")
                
                if check_column_exists(engine, 'emergency_contacts', 'relationship'):
                    conn.execute(text("""
                        ALTER TABLE emergency_contacts
                        RENAME COLUMN relationship TO contact_relationship;
                    """))
                    print("   ✅ Renamed relationship → contact_relationship")
                
                conn.commit()
            except Exception as e:
                print(f"   ⚠️  Rename warning: {e}")
            print()
            
            # Remove new columns
            print("📝 Step 3: Removing new columns...")
            conn.execute(text("""
                ALTER TABLE emergency_contacts
                DROP COLUMN IF EXISTS auto_from_guardian_id,
                DROP COLUMN IF EXISTS is_auto_generated;
            """))
            conn.commit()
            print("   ✅ Removed columns")
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
            
            # Check specific columns
            print("📋 Checking required columns:")
            checks = {
                'is_auto_generated': check_column_exists(engine, 'emergency_contacts', 'is_auto_generated'),
                'auto_from_guardian_id': check_column_exists(engine, 'emergency_contacts', 'auto_from_guardian_id'),
                'phone_number': check_column_exists(engine, 'emergency_contacts', 'phone_number'),
                'relationship': check_column_exists(engine, 'emergency_contacts', 'relationship'),
            }
            
            for col_name, exists in checks.items():
                status = "✅" if exists else "❌"
                print(f"   {status} {col_name}: {'Found' if exists else 'NOT FOUND'}")
            print()
            
            # Check indexes
            print("📋 Checking indexes:")
            indexes = inspector.get_indexes('emergency_contacts')
            index_names = [idx['name'] for idx in indexes]
            
            required_indexes = [
                'ix_emergency_contacts_is_auto_generated',
                'ix_emergency_contacts_auto_from_guardian_id'
            ]
            
            for idx_name in required_indexes:
                exists = idx_name in index_names
                status = "✅" if exists else "❌"
                print(f"   {status} {idx_name}: {'Found' if exists else 'NOT FOUND'}")
            print()
            
            # Count auto-generated contacts
            with engine.connect() as conn:
                result = conn.execute(text("""
                    SELECT 
                        COUNT(*) as total,
                        COUNT(*) FILTER (WHERE is_auto_generated = TRUE) as auto_generated,
                        COUNT(*) FILTER (WHERE is_auto_generated = FALSE) as manual
                    FROM emergency_contacts;
                """))
                row = result.fetchone()
                print(f"📊 Contact Statistics:")
                print(f"   Total contacts: {row[0]}")
                print(f"   Auto-generated: {row[1]}")
                print(f"   Manual: {row[2]}")
            print()
            
        else:
            print("   ❌ Table NOT found!")
            print("   ⚠️  Run: python migration_add_emergency_contacts.py first")
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


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Migration for auto-guardian tracking in emergency contacts")
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
        response = input("⚠️  Are you sure you want to rollback? (yes/no): ")
        if response.lower() == "yes":
            downgrade()
            verify()
        else:
            print("❌ Rollback cancelled")
    elif args.action == "verify":
        verify()