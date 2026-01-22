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
# Now import models
try:
    from models.base import Base
    from models.user import User
    from models.user_roles import UserRole
    from models.role import Role

    from models.otp import OTP



    print("\n✅ Successfully created 2 tables!")
    print("   - users")
    print("   - user_roles")
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
        
        print("\n✅ Successfully created the users table!")
        print("   - users")
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
        

if __name__ == "__main__":
    
    create_database()
    populate_roles()