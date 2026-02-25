"""
Database initialization script
Run this to create all tables in PostgreSQL
"""
import sys
import os
from pathlib import Path

# Add backend directory to Python path
current_file = Path(__file__).resolve()
backend_dir = current_file.parent.parent
sys.path.insert(0, str(backend_dir))

print(f"Backend directory: {backend_dir}")
print(f"Python path: {sys.path[0]}")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv

# Load environment variables from backend/.env
env_path = backend_dir / '.env'
load_dotenv(dotenv_path=env_path)

# Now import models
try:
    from models.base import Base
    # models/__init__.py

    from models.user import User
    from models.role import Role
    from models.user_roles import UserRole
    from models.otp import OTP
    from models.pending_dependent import PendingDependent  # Must be before qr_invitation
    from models.refresh_token import RefreshToken
    from models.qr_invitation import QRInvitation  # Depends on pending_dependent
    from models.guardian_dependent import GuardianDependent  # Depends on pending_dependent
    from models.user_voices import UserVoice

    from models.evidence import Evidence  #

    from models.dependent_safety_settings import DependentSafetySettings
    from models.device import Device
    from models.sos_event import SOSEvent

    print("\n✅ Successfully imported all models!")
except ImportError as e:
    print(f"❌ Error importing models: {e}")
    print(f"Make sure you're running from: {backend_dir}")
    sys.exit(1)

# Get database URL
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    print("❌ DATABASE_URL not found in environment variables")
    print(f"Looking for .env file at: {env_path}")
    print("Please create a .env file with DATABASE_URL")
    sys.exit(1)

print(f"Database URL: {DATABASE_URL[:30]}...")  # Show first 30 chars only


def create_database():
    """Create all tables in the database"""
    print("\n🔌 Connecting to PostgreSQL...")
    
    try:
        engine = create_engine(DATABASE_URL)
        
        print("📝 Creating tables...")
        Base.metadata.create_all(bind=engine)
        
        print("\n✅ Successfully created all tables!")
        print("\n📊 Tables created:")
        print("   1. users - User accounts")
        print("   2. roles - System roles (admin, global_user, guardian, child, elderly)")
        print("   3. user_roles - User-role assignments (many-to-many)")
        print("   4. otp - Phone verification codes")
        print("   5. pending_dependents - Dependents before QR scan")
        print("   6. refresh_tokens - JWT refresh tokens ✨ NEW")
        print("   7. qr_invitations - QR codes for linking ✨ NEW")
        print("   8. guardian_dependents - Approved guardian-dependent relationships ✨ NEW")
        print("   9. devices - Device tokens for push notifications ✨ NEW")
        print("   9. sos_events - SOS events (manual/motion) ✨ NEW")
        print("\n🔍 Verify in DBeaver - refresh and check!")
        
    except Exception as e:
        print(f"\n❌ Error creating tables: {e}")
        print("\nCommon issues:")
        print("  - PostgreSQL not running")
        print("  - Wrong password in .env file")
        print("  - Database doesn't exist")
        sys.exit(1)


def populate_roles():
    """
    Populate the roles table with the 5 default roles
    """
    print("\n🔐 Populating roles table...")
    
    try:
        from models.role import Role
        
        engine = create_engine(DATABASE_URL)
        SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
        db = SessionLocal()
        
        # Check if roles already exist
        existing_roles = db.query(Role).count()
        if existing_roles > 0:
            print(f"✓ Roles already exist ({existing_roles} roles found)")
            db.close()
            return
        
        # Define the 5 roles
        roles = [
            {
                "role_name": "admin",
                "role_description": "Developer/Admin with universal access to all features"
            },
            {
                "role_name": "global_user",
                "role_description": "Standard user with access to personal security features"
            },
            {
                "role_name": "guardian",
                "role_description": "User with global_user features plus geofencing controls and collaborations"
            },
            {
                "role_name": "child",
                "role_description": "Limited feature control, linked to guardian(s)"
            },
            {
                "role_name": "elderly",
                "role_description": "User linked to a guardian for safety monitoring"
            }
        ]
        
        # Insert roles
        for role_data in roles:
            role = Role(**role_data)
            db.add(role)
        
        db.commit()
        print(f"✅ Successfully created {len(roles)} roles!")
        print("   - admin")
        print("   - global_user")
        print("   - guardian")
        print("   - child")
        print("   - elderly")
        
        db.close()
        
    except Exception as e:
        print(f"❌ Error populating roles: {e}")
        sys.exit(1)


def verify_tables():
    """
    Verify that all tables were created successfully
    """
    print("\n🔍 Verifying tables...")
    
    try:
        from sqlalchemy import inspect
        
        engine = create_engine(DATABASE_URL)
        inspector = inspect(engine)
        
        expected_tables = [
            'users',
            'roles',
            'user_roles',
            'otps',
            'pending_dependent',
            'refresh_tokens',
            'qr_invitations',
            'guardian_dependents',
            'user_voices',
            'devices',
            'sos_events',
        ]
        
        existing_tables = inspector.get_table_names()
        
        print("\n📋 Table verification:")
        all_present = True
        for table in expected_tables:
            if table in existing_tables:
                print(f"   ✅ {table}")
            else:
                print(f"   ❌ {table} - MISSING!")
                all_present = False
        
        if all_present:
            print("\n🎉 All tables created successfully!")
        else:
            print("\n⚠️  Some tables are missing. Please check for errors above.")
            
    except Exception as e:
        print(f"❌ Error verifying tables: {e}")


if __name__ == "__main__":
    print("=" * 60)
    print("🚀 PERSONAL SECURITY SYSTEM - DATABASE INITIALIZATION")
    print("=" * 60)
    
    create_database()
    populate_roles()
    verify_tables()
    
    print("\n" + "=" * 60)
    print("✅ DATABASE SETUP COMPLETE!")
    print("=" * 60)
    print("\n📌 Next steps:")
    print("   1. Verify tables in DBeaver")
    print("   2. Test registration endpoint: POST /api/auth/register")
    print("   3. Test login endpoint: POST /api/auth/login")
    print("   4. Check refresh token endpoint: POST /api/auth/refresh")
    print("\n💡 To reset database:")
    print("   - Drop all tables in DBeaver")
    print("   - Run this script again")
    print("\n")