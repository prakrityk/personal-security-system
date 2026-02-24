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
            print("🔥 INITIALIZING FIREBASE ADMIN SDK...")
            # backend/ directory
            BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            print(f"📁 BASE_DIR: {BASE_DIR}")

            creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
            print(f"📁 CREDS_PATH from env: {creds_path}")

            if not creds_path:
                creds_path = os.path.join(BASE_DIR, "firebase-credentials.json")
                print(f"📁 Using default path: {creds_path}")

            if not os.path.isabs(creds_path):
                creds_path = os.path.join(BASE_DIR, creds_path)
                print(f"📁 Made absolute: {creds_path}")

            if not os.path.exists(creds_path):
                print(f"❌ Firebase credentials file NOT FOUND at: {creds_path}")
                raise FileNotFoundError(
                    f"Firebase credentials file not found at: {creds_path}"
                )
            
            print(f"✅ Firebase credentials file FOUND at: {creds_path}")

            cred = credentials.Certificate(creds_path)
            print(f"✅ Firebase credentials loaded successfully")

            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred)
                print("✅ Firebase Admin SDK initialized successfully")
            else:
                print("✅ Firebase Admin SDK already initialized")

        except Exception as e:
            print(f"❌ Firebase initialization failed: {e}")
            import traceback
            traceback.print_exc()
            raise

    # -----------------------------
    # Token verification (existing)
    # -----------------------------

    def verify_firebase_token(self, id_token: str) -> dict:
        """Verify Firebase ID token from Flutter app."""
        try:
            decoded_token = auth.verify_id_token(id_token)

            uid = decoded_token.get("uid")
            email = decoded_token.get("email")
            phone_number = decoded_token.get("phone_number")
            email_verified = decoded_token.get("email_verified", False)
            
            # Check if phone is verified by looking at provider data
            phone_verified = False
            provider_data = decoded_token.get("firebase", {}).get("sign_in_provider")
            
            # If user has phone number and signed in with phone, it's verified
            if phone_number:
                # Phone is verified if it's in the token (Firebase only adds verified phones)
                phone_verified = True
                
            # Alternative: Check provider data
            if not phone_verified and provider_data == "phone":
                phone_verified = True

            print(f"🔍 Token verification result:")
            print(f"   UID: {uid}")
            print(f"   Email: {email}")
            print(f"   Phone: {phone_number}")
            print(f"   Email Verified: {email_verified}")
            print(f"   Phone Verified: {phone_verified}")

            return {
                "uid": uid,
                "email": email,
                "phone_number": phone_number,
                "email_verified": email_verified,
                "phone_verified": phone_verified,
                "verified": True,  # Keep for backward compatibility
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
            print(f"❌ Token verification error: {e}")
            import traceback
            traceback.print_exc()
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
        print(f"\n🔥🔥🔥 FIREBASE SERVICE: send_sos_notification CALLED")
        
        token_list = [t for t in tokens if t]
        print(f"📋 Raw tokens received: {len(tokens)}")
        print(f"📋 Valid tokens after filter: {len(token_list)}")
        
        if not token_list:
            print("⚠️ No valid FCM tokens to send notification to")
            return

        # Print first few tokens for debugging
        for i, token in enumerate(token_list[:3]):
            print(f"📋 Token {i}: {token[:30]}...")
        
        if len(token_list) > 3:
            print(f"📋 ... and {len(token_list) - 3} more tokens")

        # Convert data values to strings
        str_data = {k: str(v) for k, v in (data or {}).items()}
        print(f"📦 Formatted data payload: {str_data}")

        success_count = 0
        failure_count = 0
        expired_tokens = []

        # Send to each token individually
        for idx, token in enumerate(token_list):
            try:
                print(f"📨 Attempting to send to token {idx}...")
                
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data=str_data,
                    token=token,
                )
                
                response = messaging.send(message)
                print(f"✅ FCM notification sent to token {idx}: {response}")
                success_count += 1
                
            except messaging.UnregisteredError as e:
                print(f"⚠️ Token expired (UnregisteredError): {token[:30]}...")
                print(f"   Error: {e}")
                expired_tokens.append(token)
                failure_count += 1
            except messaging.InvalidArgumentError as e:
                print(f"⚠️ Invalid token format: {token[:30]}...")
                print(f"   Error: {e}")
                expired_tokens.append(token)
                failure_count += 1
            except messaging.SenderIdMismatchError as e:
                print(f"⚠️ Sender ID mismatch: {token[:30]}...")
                print(f"   Error: {e}")
                failure_count += 1
            except messaging.ThirdPartyAuthError as e:
                print(f"⚠️ Third party auth error: {e}")
                failure_count += 1
            except messaging.QuotaExceededError as e:
                print(f"⚠️ Quota exceeded: {e}")
                failure_count += 1
            except Exception as e:
                print(f"❌ Failed to send to token {idx}: {e}")
                print(f"   Error type: {type(e)}")
                import traceback
                traceback.print_exc()
                failure_count += 1

        # 🔥 CLEAN UP EXPIRED TOKENS
        if expired_tokens:
            print(f"🧹 Cleaning up {len(expired_tokens)} expired tokens...")
            self._cleanup_expired_tokens(expired_tokens)

        print(
            f"📊 FCM BATCH SUMMARY: success={success_count}, failure={failure_count}, "
            f"expired={len(expired_tokens)}"
        )

    def _cleanup_expired_tokens(self, expired_tokens: list[str]) -> None:
        """Remove expired tokens from database"""
        try:
            print(f"🧹 Cleaning up {len(expired_tokens)} expired tokens...")
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


# ✅ Create singleton instance at module load
print("🔥 Creating FirebaseService singleton instance...")
firebase_service = FirebaseService()

def get_firebase_service() -> FirebaseService:
    """Get the singleton FirebaseService instance"""
    print("🔥 get_firebase_service() called")
    return firebase_service