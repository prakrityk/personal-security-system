"""
Firebase Token Test Script
Use this to test if your Firebase Admin SDK is working correctly
"""
import sys
import os

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.firebase_service import firebase_service


def test_firebase_token():
    """
    Test Firebase token verification
    
    Usage:
    1. Get a Firebase ID token from your Flutter app (check console logs)
    2. Run: python test_firebase_token.py <your_token_here>
    """
    if len(sys.argv) < 2:
        print("❌ Usage: python test_firebase_token.py <firebase_id_token>")
        print("\n📝 How to get a Firebase ID token:")
        print("   1. Run your Flutter app")
        print("   2. After phone verification, check console for token")
        print("   3. Copy the token and run this script with it")
        sys.exit(1)
    
    test_token = sys.argv[1]
    
    print("🔍 Testing Firebase token verification...")
    print(f"📝 Token length: {len(test_token)}")
    print(f"📝 Token starts with: {test_token[:50]}...")
    print()
    
    try:
        result = firebase_service.verify_firebase_token(test_token)
        
        print("✅ Token verified successfully!")
        print()
        print("📋 User Information:")
        print(f"   UID: {result['uid']}")
        print(f"   Email: {result.get('email', 'N/A')}")
        print(f"   Phone: {result.get('phone_number', 'N/A')}")
        print(f"   Email Verified: {result.get('email_verified', False)}")
        print(f"   Phone Verified: {result.get('phone_verified', False)}")
        print()
        print("✅ Firebase Admin SDK is working correctly!")
        
    except Exception as e:
        print(f"❌ Token verification failed: {e}")
        print()
        print("🔧 Troubleshooting:")
        print("   1. Check if FIREBASE_CREDENTIALS_PATH is set in .env")
        print("   2. Verify firebase-credentials.json exists at the specified path")
        print("   3. Make sure the token is not expired (Firebase tokens expire after 1 hour)")
        print("   4. Ensure the credentials file matches your Firebase project")
        sys.exit(1)


if __name__ == "__main__":
    test_firebase_token()