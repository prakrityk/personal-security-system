"""
Firebase Admin SDK Service
Handles Firebase token verification and user management
"""
import firebase_admin
from firebase_admin import credentials, auth
from fastapi import HTTPException, status
import os
import logging
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)


class FirebaseService:
    _initialized = False
    _project_id = None
    
    @classmethod
    def initialize(cls):
        """Initialize Firebase Admin SDK (call once at startup)"""
        if cls._initialized:
            logger.info("✅ Firebase already initialized")
            return
        
        try:
            # Get path to Firebase credentials
            cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "./firebase_credentials.json")
            
            logger.info(f"🔍 Looking for Firebase credentials at: {cred_path}")
            
            if not os.path.exists(cred_path):
                error_msg = (
                    f"Firebase credentials file not found at: {cred_path}\n"
                    "Please download from Firebase Console > Project Settings > Service Accounts > "
                    "Generate New Private Key"
                )
                logger.error(f"❌ {error_msg}")
                raise FileNotFoundError(error_msg)
            
            # Initialize Firebase Admin
            cred = credentials.Certificate(cred_path)
            
            # Store project ID for verification
            cls._project_id = cred.project_id
            
            # Check if already initialized (safety check)
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)
                logger.info("✅ Firebase Admin SDK initialized successfully")
            else:
                logger.info("✅ Firebase Admin SDK already initialized")
            
            cls._initialized = True
            logger.info(f"📋 Firebase Project ID: {cls._project_id}")
            logger.info(f"📧 Service Account: {cred.service_account_email}")
            
        except FileNotFoundError as e:
            logger.error(f"❌ Credentials file not found: {e}")
            raise
        except Exception as e:
            logger.error(f"❌ Failed to initialize Firebase Admin SDK: {e}")
            logger.error(f"   Error type: {type(e).__name__}")
            raise
    
    @classmethod
    def ensure_initialized(cls):
        """Ensure Firebase is initialized before use"""
        if not cls._initialized:
            logger.warning("⚠️ Firebase not initialized, initializing now...")
            cls.initialize()
    
    @classmethod
    def verify_firebase_token(cls, firebase_token: str) -> dict:
        """
        Verify Firebase ID token and extract user information
        
        Args:
            firebase_token: Firebase ID token from Flutter client
            
        Returns:
            dict with user info: {
                'uid': str,
                'email': str,
                'email_verified': bool,
                'phone_number': str,
                'phone_verified': bool
            }
            
        Raises:
            HTTPException: If token is invalid or expired
        """
        # Ensure Firebase is initialized
        cls.ensure_initialized()
        
        if not firebase_token:
            logger.error("❌ Empty token received")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Firebase token is required"
            )
        
        # Clean token (remove whitespace)
        firebase_token = firebase_token.strip()
        
        try:
            logger.info("🔍 Verifying Firebase token...")
            logger.info(f"   Token length: {len(firebase_token)}")
            logger.info(f"   Token preview: {firebase_token[:50]}...")
            logger.info(f"   Expected project: {cls._project_id}")
            
            # Verify the token with Firebase Admin SDK
            decoded_token = auth.verify_id_token(firebase_token, check_revoked=True)
            
            logger.info("✅ Token verified successfully")
            
            # Extract user information
            uid = decoded_token.get('uid')
            email = decoded_token.get('email')
            email_verified = decoded_token.get('email_verified', False)
            phone_number = decoded_token.get('phone_number')
            
            # Check if phone is verified (if phone auth was used, it's auto-verified)
            phone_verified = bool(phone_number)
            
            # Log extracted info
            logger.info(f"📋 User Info:")
            logger.info(f"   UID: {uid}")
            logger.info(f"   Email: {email}")
            logger.info(f"   Phone: {phone_number}")
            logger.info(f"   Email Verified: {email_verified}")
            logger.info(f"   Phone Verified: {phone_verified}")
            
            return {
                'uid': uid,
                'email': email,
                'email_verified': email_verified,
                'phone_number': phone_number,
                'phone_verified': phone_verified
            }
            
        except auth.RevokedIdTokenError as e:
            logger.error(f"❌ Token revoked: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Firebase token has been revoked. Please login again."
            )
            
        except auth.ExpiredIdTokenError as e:
            logger.error(f"❌ Token expired: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Firebase token has expired. Please refresh and try again."
            )
            
        except auth.InvalidIdTokenError as e:
            logger.error(f"❌ Invalid token: {str(e)}")
            logger.error(f"   Token length: {len(firebase_token)}")
            logger.error(f"   Token starts: {firebase_token[:30]}")
            logger.error(f"   Expected project: {cls._project_id}")
            logger.error("\n🔍 Common causes:")
            logger.error("   1. Token from different Firebase project")
            logger.error("   2. Token corrupted during transmission")
            logger.error("   3. Wrong service account credentials")
            
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=(
                    f"Invalid Firebase token. Common causes: "
                    f"(1) Token from different Firebase project (expected: {cls._project_id}), "
                    f"(2) Token expired or corrupted, "
                    f"(3) Service account credentials mismatch"
                )
            )
            
        except Exception as e:
            logger.error(f"❌ Unexpected error: {str(e)}")
            logger.error(f"   Error type: {type(e).__name__}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Token verification failed: {str(e)}"
            )
    
    @classmethod
    def get_user_by_uid(cls, firebase_uid: str):
        """
        Get Firebase user by UID
        
        Args:
            firebase_uid: Firebase user UID
            
        Returns:
            UserRecord object from Firebase
        """
        cls.ensure_initialized()
        
        try:
            user = auth.get_user(firebase_uid)
            return user
        except auth.UserNotFoundError:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Firebase user not found"
            )
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to fetch Firebase user: {str(e)}"
            )
    
    @classmethod
    def verify_email_and_phone(cls, firebase_uid: str) -> dict:
        """
        Check if user's email and phone are verified in Firebase
        
        Args:
            firebase_uid: Firebase user UID
            
        Returns:
            dict: {'email_verified': bool, 'phone_verified': bool}
        """
        cls.ensure_initialized()
        
        try:
            user = auth.get_user(firebase_uid)
            
            return {
                'email_verified': user.email_verified,
                'phone_verified': bool(user.phone_number)  # If phone exists, it's verified
            }
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to verify user: {str(e)}"
            )
    
    @classmethod
    def get_project_id(cls) -> str:
        """Get the Firebase project ID"""
        cls.ensure_initialized()
        return cls._project_id


# Create singleton instance
firebase_service = FirebaseService()