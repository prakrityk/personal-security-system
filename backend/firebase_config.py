"""
Firebase Configuration Module
Initializes Firebase Admin SDK for backend token verification
"""
import firebase_admin
from firebase_admin import credentials, auth
import os
import logging

logger = logging.getLogger(__name__)


def initialize_firebase():
    """
    Initialize Firebase Admin SDK with service account credentials
    
    Raises:
        ValueError: If FIREBASE_CREDENTIALS_PATH environment variable is not set
        FileNotFoundError: If credentials file doesn't exist at specified path
    """
    try:
        # Check if Firebase is already initialized
        if firebase_admin._apps:
            logger.info("ℹ️  Firebase Admin SDK already initialized")
            return
        
        # Get credentials path from environment
        cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
        
        if not cred_path:
            raise ValueError(
                "❌ FIREBASE_CREDENTIALS_PATH not found in environment variables. "
                "Please set it in your .env file."
            )
        
        # Expand path if using relative path
        cred_path = os.path.abspath(os.path.expanduser(cred_path))
        
        if not os.path.exists(cred_path):
            raise FileNotFoundError(
                f"❌ Firebase credentials file not found at: {cred_path}\n"
                f"   Current working directory: {os.getcwd()}\n"
                f"   Please verify the path in your .env file."
            )
        
        logger.info(f"📂 Loading Firebase credentials from: {cred_path}")
        
        # Initialize Firebase with service account
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        
        logger.info("✅ Firebase Admin SDK initialized successfully")
        
        # Optional: Test the initialization
        try:
            # This will verify the credentials are valid
            auth.list_users(max_results=1)
            logger.info("✅ Firebase Admin SDK credentials verified")
        except Exception as e:
            logger.warning(f"⚠️  Firebase credentials loaded but verification failed: {e}")
            
    except Exception as e:
        logger.error(f"❌ Failed to initialize Firebase Admin SDK: {str(e)}")
        raise


# Initialize Firebase when this module is imported
try:
    initialize_firebase()
except Exception as e:
    logger.critical(
        f"🚨 CRITICAL: Firebase initialization failed on module import: {e}\n"
        f"   The application may not function correctly."
    )
    # Re-raise to prevent app from starting with invalid Firebase config
    raise