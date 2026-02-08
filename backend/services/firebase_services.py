"""
Firebase Admin SDK service

Originally used only for token verification.
Extended to also send FCM push notifications for SOS events.
"""
print("🔥 LOADED firebase_services.py FROM:", __file__)

import os
from dotenv import load_dotenv
from typing import Iterable, Optional
import firebase_admin
from fastapi import HTTPException
from firebase_admin import auth, credentials, messaging

load_dotenv()

class FirebaseService:
    """
    Firebase service (singleton)
    - Initializes Admin SDK once
    - Verifies Firebase ID tokens
    - Sends FCM notifications
    - Cleans up expired tokens
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
            # backend/ directory
            BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

            creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH")

            if not creds_path:
                creds_path = os.path.join(BASE_DIR, "firebase-credentials.json")

            if not os.path.isabs(creds_path):
                creds_path = os.path.join(BASE_DIR, creds_path)

            if not os.path.exists(creds_path):
                raise FileNotFoundError(
                    f"Firebase credentials file not found at: {creds_path}"
                )

            cred = credentials.Certificate(creds_path)

            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)

            print("✅ Firebase Admin SDK initialized successfully")

        except Exception as e:
            print(f"❌ Firebase initialization failed: {e}")
            raise

    # -----------------------------
    # Token verification (existing)
    # -----------------------------
    def verify_firebase_token(self, id_token: str) -> dict:
        """Verify Firebase ID token from Flutter app."""
        try:
            decoded_token = auth.verify_id_token(id_token)

            phone_number = decoded_token.get("phone_number")
            uid = decoded_token.get("uid")

            if not phone_number:
                raise HTTPException(
                    status_code=400,
                    detail="Phone number not found in Firebase token",
                )

            return {
                "uid": uid,
                "phone_number": phone_number,
                "verified": True,
            }

        except auth.ExpiredIdTokenError:
            raise HTTPException(
                status_code=401,
                detail="Firebase token has expired",
            )
        except auth.RevokedIdTokenError:
            raise HTTPException(
                status_code=401,
                detail="Firebase token has been revoked",
            )
        except auth.InvalidIdTokenError:
            raise HTTPException(
                status_code=401,
                detail="Invalid Firebase token",
            )
        except Exception as e:
            raise HTTPException(
                status_code=401,
                detail=f"Firebase token verification failed: {str(e)}",
            )

    def get_user_by_phone(self, phone_number: str) -> Optional[dict]:
        """Get Firebase user by phone number."""
        try:
            user = auth.get_user_by_phone_number(phone_number)
            return {
                "uid": user.uid,
                "phone_number": user.phone_number,
                "created_at": user.user_metadata.creation_timestamp,
            }
        except auth.UserNotFoundError:
            return None
        except Exception as e:
            print(f"Error getting user by phone: {str(e)}")
            return None

    # -----------------------------
    # FCM helpers with token cleanup
    # -----------------------------
    def send_sos_notification(
        self,
        tokens: Iterable[str],
        title: str,
        body: str,
        data: Optional[dict] = None,
    ) -> None:
        """
        Send FCM notifications to multiple device tokens and clean up expired tokens.

        - tokens: list of FCM tokens
        - title/body: notification content
        - data: small key/value payload (e.g. {"event_id": "...", "type": "SOS_EVENT"})
        """
        token_list = [t for t in tokens if t]
        if not token_list:
            print("⚠️ No valid FCM tokens to send notification to")
            return

        # Convert data values to strings
        str_data = {k: str(v) for k, v in (data or {}).items()}

        success_count = 0
        failure_count = 0
        expired_tokens = []

        # Send to each token individually
        for idx, token in enumerate(token_list):
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data=str_data,
                    token=token,
                )
                
                response = messaging.send(message)
                print(f"✅ FCM notification sent to token {idx}: {response}")
                success_count += 1
                
            except messaging.UnregisteredError:
                print(f"⚠️ Token expired: {token[:20]}...")
                expired_tokens.append(token)
                failure_count += 1
            except messaging.InvalidArgumentError:
                print(f"⚠️ Invalid token format: {token[:20]}...")
                expired_tokens.append(token)
                failure_count += 1
            except Exception as e:
                print(f"❌ Failed to send to token {idx}: {e}")
                failure_count += 1

        # 🔥 CLEAN UP EXPIRED TOKENS
        if expired_tokens:
            self._cleanup_expired_tokens(expired_tokens)

        print(
            f"📨 FCM batch: success={success_count}, failure={failure_count}, "
            f"expired={len(expired_tokens)}"
        )

    def _cleanup_expired_tokens(self, expired_tokens: list[str]) -> None:
        """Remove expired tokens from database"""
        try:
            # Import here to avoid circular imports
            from database.connection import get_db
            from sqlalchemy.orm import Session
            
            # Get a database session
            db = next(get_db())
            
            # Import Device model
            from models.device import Device
            
            # Mark tokens as inactive
            result = db.query(Device).filter(
                Device.fcm_token.in_(expired_tokens)
            ).update(
                {"is_active": False},
                synchronize_session=False
            )
            
            db.commit()
            print(f"✅ Marked {result} expired tokens as inactive")
            
            # Optional: Also delete completely if you prefer
            # db.query(Device).filter(Device.fcm_token.in_(expired_tokens)).delete(synchronize_session=False)
            # db.commit()
            # print(f"✅ Deleted {result} expired tokens")
            
        except ImportError as e:
            print(f"⚠️ Could not import database modules for token cleanup: {e}")
            print("⚠️ Make sure database.connection and models.device are available")
        except Exception as e:
            print(f"❌ Failed to cleanup tokens: {e}")
            import traceback
            traceback.print_exc()


# Singleton instance
firebase_service = None

def get_firebase_service() -> FirebaseService:
    """Get or create the singleton FirebaseService instance"""
    global firebase_service
    if firebase_service is None:
        firebase_service = FirebaseService()
    return firebase_service