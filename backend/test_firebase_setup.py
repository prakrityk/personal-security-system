"""
Test Firebase Admin SDK Setup
Run this to verify Firebase credentials are working
"""
import sys
import os
from pathlib import Path

# Add backend directory to path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

from services.firebase_service import firebase_service

def test_firebase_initialization():
    """Test Firebase Admin SDK initialization"""
    print("=" * 60)
    print("🔥 TESTING FIREBASE ADMIN SDK SETUP")
    print("=" * 60)
    
    try:
        # Initialize Firebase
        firebase_service.initialize()
        print("\n✅ Firebase Admin SDK initialized successfully!")
        print("\n📋 Next steps:")
        print("   1. Test with a real Firebase token from Flutter")
        print("   2. Verify token using firebase_service.verify_firebase_token()")
        print("\n")
        
    except FileNotFoundError as e:
        print(f"\n❌ Error: {e}")
        print("\n📝 To fix:")
        print("   1. Go to Firebase Console > Project Settings > Service Accounts")
        print("   2. Click 'Generate New Private Key'")
        print("   3. Save as 'firebase_credentials.json' in backend folder")
        print("   4. Add to .gitignore to keep it secure")
        print("\n")
        sys.exit(1)
        
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    test_firebase_initialization()