"""
Firebase Admin SDK service
Handles Firebase token verification (OTP sending handled by Flutter)
"""
import os
import firebase_admin
from firebase_admin import credentials, auth
from fastapi import HTTPException
from typing import Optional


class FirebaseService:
    """
    Firebase service for verifying Firebase ID tokens
    Singleton pattern to ensure single Firebase initialization
    """
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(FirebaseService, cls).__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not self._initialized:
            self._initialize_firebase()
            self.__class__._initialized = True
    
    def _initialize_firebase(self):
        """Initialize Firebase Admin SDK"""
        try:
            # Get credentials path from environment or use default
            creds_path = os.getenv(
                'FIREBASE_CREDENTIALS_PATH',
                'firebase-credentials.json'
            )
            
            if not os.path.exists(creds_path):
                raise FileNotFoundError(
                    f"Firebase credentials file not found at: {creds_path}\n"
                    "Please ensure firebase-credentials.json is in your project root."
                )
            
            # Initialize Firebase Admin
            cred = credentials.Certificate(creds_path)
            firebase_admin.initialize_app(cred)
            
            print("✅ Firebase Admin SDK initialized successfully")
            
        except Exception as e:
            print(f"❌ Firebase initialization failed: {str(e)}")
            raise
    
    def verify_firebase_token(self, id_token: str) -> dict:
        """
        Verify Firebase ID token from Flutter app
        
        Args:
            id_token: Firebase ID token from client after phone verification
            
        Returns:
            Decoded token with user info including phone_number
            
        Raises:
            HTTPException: If token is invalid
        """
        try:
            # Verify the token
            decoded_token = auth.verify_id_token(id_token)
            
            # Extract phone number
            phone_number = decoded_token.get('phone_number')
            uid = decoded_token.get('uid')
            
            if not phone_number:
                raise HTTPException(
                    status_code=400,
                    detail="Phone number not found in Firebase token"
                )
            
            return {
                "uid": uid,
                "phone_number": phone_number,
                "verified": True
            }
            
        except auth.ExpiredIdTokenError:
            raise HTTPException(
                status_code=401,
                detail="Firebase token has expired"
            )
        except auth.RevokedIdTokenError:
            raise HTTPException(
                status_code=401,
                detail="Firebase token has been revoked"
            )
        except auth.InvalidIdTokenError:
            raise HTTPException(
                status_code=401,
                detail="Invalid Firebase token"
            )
        except Exception as e:
            raise HTTPException(
                status_code=401,
                detail=f"Firebase token verification failed: {str(e)}"
            )
    
    def get_user_by_phone(self, phone_number: str) -> Optional[dict]:
        """
        Get Firebase user by phone number
        
        Args:
            phone_number: Phone number in format +977XXXXXXXXXX
            
        Returns:
            User data if exists, None otherwise
        """
        try:
            user = auth.get_user_by_phone_number(phone_number)
            return {
                "uid": user.uid,
                "phone_number": user.phone_number,
                "created_at": user.user_metadata.creation_timestamp
            }
        except auth.UserNotFoundError:
            return None
        except Exception as e:
            print(f"Error getting user by phone: {str(e)}")
            return None


# Singleton instance
firebase_service = FirebaseService()