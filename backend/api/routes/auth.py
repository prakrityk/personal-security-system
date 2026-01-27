"""
Authentication routes with Firebase Phone Authentication
Handles user registration, login, phone verification, and token management

Flow: Flutter sends OTP via Firebase → Backend verifies Firebase token
"""
from datetime import timedelta
from sqlalchemy.sql import func
from datetime import datetime, timezone

from typing import List, Optional  
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_,desc
from typing import List
import random

# Schemas
from api.schemas.auth import (
    UserRegister,
    UserLogin,
    UserResponse,
    Token,
    EmailCheckResponse,
    RoleInfo,
    RoleSelectRequest,
    TokenResponse,
    RefreshTokenRequest,
    UserWithTokens
)

# Models
from models.user import User
from models.pending_user import PendingUser
from models.role import Role
from models.user_roles import UserRole
from models.otp import OTP

# Auth utilities
from api.dependencies.auth import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
    create_refresh_token,
    verify_refresh_token,
    revoke_refresh_token,
    revoke_all_user_tokens
)

# Firebase service
from services.firebase_service import firebase_service

# Phone validator
from utils.phone_validator import clean_phone_number, validate_phone_number

# DB
from database.connection import get_db

# Router
router = APIRouter()


# ================================================
# SECTION 1: FIREBASE PHONE VERIFICATION
# ================================================

@router.post("/verify-firebase-token")
async def verify_firebase_token(
    firebase_token: str,
    db: Session = Depends(get_db)
):
    """
    Verify Firebase ID token from Flutter app
    This confirms phone number was verified by Firebase
    
    Flow:
    1. Flutter sends OTP via Firebase SDK
    2. User enters OTP in Flutter
    3. Firebase verifies and returns ID token
    4. Flutter sends token to this endpoint
    5. Backend verifies token and extracts phone number
    """
    try:
        # Verify Firebase token
        firebase_data = firebase_service.verify_firebase_token(firebase_token)
        
        phone_number = firebase_data["phone_number"]
        
        # Clean phone number (ensure correct format)
        try:
            cleaned_phone = clean_phone_number(phone_number)
        except:
            # Firebase phone is already in international format
            cleaned_phone = phone_number
        
        # Mark phone as verified in OTP table (for tracking)
        otp_entry = db.query(OTP).filter(
            OTP.phone_number == cleaned_phone,
            OTP.is_verified == False
        ).order_by(OTP.created_at.desc()).first()
        
        if otp_entry:
            otp_entry.is_verified = True
            db.commit()
        else:
            # Create new verified entry
            new_otp = OTP(
                phone_number=cleaned_phone,
                code="firebase_verified",
                attempts=0,
                is_verified=True
            )
            db.add(new_otp)
            db.commit()
        
        return {
            "success": True,
            "message": "Phone verified successfully",
            "phone_number": cleaned_phone,
            "firebase_uid": firebase_data["uid"]
        }
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Token verification failed: {str(e)}"
        )


# ================================================
# SECTION 2: REGISTRATION WITH FIREBASE
# ================================================

@router.post("/register-with-firebase", response_model=UserWithTokens)
async def register_with_firebase(
    full_name: str,
    email: str,
    phone_number: str,
    password: str,
    firebase_token: str,
    db: Session = Depends(get_db)
):
    """
    Register user with Firebase-verified phone number
    
    Flow:
    1. User verifies phone via Firebase (in Flutter)
    2. Flutter sends: user data + Firebase token
    3. Backend verifies token
    4. Backend creates user account
    """
    try:
        # Verify Firebase token first
        firebase_data = firebase_service.verify_firebase_token(firebase_token)
        verified_phone = firebase_data["phone_number"]
        
        # Clean phone numbers
        try:
            cleaned_verified = clean_phone_number(verified_phone)
        except:
            cleaned_verified = verified_phone
            
        try:
            cleaned_input = clean_phone_number(phone_number)
        except:
            cleaned_input = phone_number
        
        # Ensure the phone in request matches Firebase verified phone
        if cleaned_input != cleaned_verified:
            raise HTTPException(
                status_code=400,
                detail="Phone number mismatch with Firebase verification"
            )
        
        # Check if user already exists
        existing_user = db.query(User).filter(
            or_(User.email == email, User.phone_number == cleaned_input)
        ).first()
        
        if existing_user:
            raise HTTPException(
                status_code=400,
                detail="User already exists with this email or phone"
            )
        
        # Create user directly (phone is verified by Firebase)
        user = User(
            full_name=full_name,
            email=email,
            phone_number=cleaned_input,
            hashed_password=hash_password(password),
            email_verified=False,  # Can add email verification later
            phone_verified=True,   # Verified by Firebase
            is_active=True
        )
        
        db.add(user)
        db.commit()
        db.refresh(user)
        
        # Create tokens
        access_token = create_access_token(data={"sub": str(user.id), "email": user.email})
        refresh_token_obj = create_refresh_token(user_id=user.id, db=db)
        
        # Get user roles
        user_roles = db.query(Role).join(UserRole).filter(UserRole.user_id == user.id).all()
        
        user_response = UserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            phone_number=user.phone_number,
            roles=[
                RoleInfo(
                    id=role.id,
                    role_name=role.role_name,
                    role_description=role.role_description
                )
                for role in user_roles
            ]
        )
        
        tokens = TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token_obj.token,
            token_type="bearer",
            expires_in=1800
        )
        
        return UserWithTokens(user=user_response, tokens=tokens)
        
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Registration failed: {str(e)}"
        )

<<<<<<< HEAD
=======
    # Correct OTP → mark as verified
    otp.is_verified = True
    db.commit()

    return {
        "success": True,
        "message": "Phone verified successfully"
    }


@router.get("/check-phone")
async def check_phone(phone_number: str, db: Session = Depends(get_db)):
    """
    Check if phone is available and/or verified (for prefill in registration)
    """
    otp_entry = db.query(OTP).filter(
        OTP.phone_number == phone_number,
        OTP.is_verified == True
    ).order_by(OTP.created_at.desc()).first()

    if otp_entry:
        return {"available": True, "phone_number": phone_number, "prefill": True}
    else:
        return {"available": False, "phone_number": phone_number, "prefill": False}


# ================================================
# SECTION 2: REGISTRATION
# ================================================

@router.post("/register", status_code=status.HTTP_200_OK)
async def register(user_data: UserRegister, db: Session = Depends(get_db)):

    """
    Register a new user with refresh token
    Only allows registration if phone number is verified
    """

   # 1. Check phone verified (unchanged)
    otp_verified = db.query(OTP).filter(
        OTP.phone_number == user_data.phone_number,
        OTP.is_verified == True
    ).order_by(OTP.created_at.desc()).first()
    
    print("Checking OTP for phone:", user_data.phone_number)
    print("OTP record found:", otp_verified)


    if not otp_verified:
        raise HTTPException(
            status_code=400,
            detail="Phone number not verified. Please verify before registering."
        )

    # 2. If user already exists → must login
    if db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(
            status_code=400,
            detail="Email already registered. Please login."
        )

    # 3. Generate email OTP
    email_otp = str(random.randint(100000, 999999))

    # 4. Check if pending already exists
    pending = db.query(PendingUser).filter(
        PendingUser.email == user_data.email
    ).order_by(PendingUser.created_at.desc()).first()

    if pending:
        # resend OTP
        pending.email_otp = email_otp
        pending.otp_attempts = 0
        db.commit()
    else:
        # create new pending
        pending = PendingUser(
            full_name=user_data.full_name,
            email=user_data.email,
            phone_number=user_data.phone_number,
            hashed_password=hash_password(user_data.password),
            email_otp=email_otp
        )
        db.add(pending)
        db.commit()

    # simulate email sending
    print(f"📧 Email OTP for {user_data.email}: {email_otp}")

    return {
        "success": True,
        "message": "Email verification OTP sent"
    }

>>>>>>> 008fb737f3016194a109b20e536adbcfa8ae3e94

# ================================================
# SECTION 3: LOGIN
# ================================================

@router.post("/login", response_model=UserWithTokens)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """
    Login with email or phone number
    Returns user profile with access token and refresh token
    
    Phone number is automatically cleaned for lookup
    """
    
    # Check if login identifier is a phone number
    login_identifier = login_data.email
    if login_identifier and any(char.isdigit() for char in login_identifier):
        try:
            login_identifier = clean_phone_number(login_identifier)
        except:
            pass  # If cleaning fails, use as-is (might be email)
    
    user = db.query(User).filter(
        or_(User.email == login_identifier, User.phone_number == login_identifier)
    ).first()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    # Create access token
    access_token = create_access_token(data={"sub": str(user.id), "email": user.email})

    # Create refresh token
    refresh_token_obj = create_refresh_token(user_id=user.id, db=db)

    # Get user roles
    user_roles = db.query(Role).join(UserRole).filter(UserRole.user_id == user.id).all()

    user_response = UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        phone_number=user.phone_number,
        roles=[
            RoleInfo(
                id=role.id,
                role_name=role.role_name,
                role_description=role.role_description
            )
            for role in user_roles
        ]
    )

    tokens = TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_obj.token,
        token_type="bearer",
        expires_in=1800
    )

    return UserWithTokens(user=user_response, tokens=tokens)


# ================================================
# SECTION 4: TOKEN MANAGEMENT
# ================================================

@router.post("/refresh", response_model=TokenResponse)
async def refresh_access_token(request: RefreshTokenRequest, db: Session = Depends(get_db)):
    """
    Get new access token using refresh token
    Implements token rotation for security (old refresh token is revoked)
    """
    refresh_token = verify_refresh_token(request.refresh_token, db)
    
    if not refresh_token:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired refresh token"
        )
    
    user = db.query(User).filter(User.id == refresh_token.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    access_token = create_access_token(data={"sub": str(user.id), "email": user.email})
    
    new_refresh_token = create_refresh_token(user_id=user.id, db=db)
    revoke_refresh_token(request.refresh_token, db)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=new_refresh_token.token,
        token_type="bearer",
        expires_in=1800
    )

# In api/routes/auth.py
# api/routes/auth.py
# FIXED logout endpoint

@router.post("/logout")
async def logout(
    request: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
<<<<<<< HEAD
    """Logout user by revoking the refresh token"""
    revoke_refresh_token(request.refresh_token, db)
    
    return {
        "success": True,
        "message": "Logged out successfully"
    }
=======
    """
    Logout user by revoking the refresh token
    NOTE: Does NOT require current_user - token might be invalid
    """
    try:
        print(f"🔄 Logout request received")
        print(f"📦 Refresh token: {request.refresh_token[:20]}..." if request.refresh_token else "❌ No token")
        
        # Try to revoke the token
        result = revoke_refresh_token(request.refresh_token, db)
        
        if result:
            print("✅ Token revoked successfully")
            return {
                "success": True,
                "message": "Logged out successfully"
            }
        else:
            # Token not found or already revoked - still return success
            print("ℹ️ Token not found or already revoked")
            return {
                "success": True,
                "message": "Already logged out"
            }
    except Exception as e:
        print(f"❌ Logout error: {e}")
        # Always return success for logout - don't fail the user
        return {
            "success": True,
            "message": "Logged out"
        }
>>>>>>> 008fb737f3016194a109b20e536adbcfa8ae3e94


@router.post("/logout-all")
async def logout_all_devices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
<<<<<<< HEAD
    """Logout from all devices by revoking all refresh tokens for the user"""
    revoke_all_user_tokens(current_user.id, db)
    
    return {
        "success": True,
        "message": "Logged out from all devices successfully"
    }
=======
    """
    Logout from all devices by revoking all refresh tokens for the user
    """
    try:
        revoke_all_user_tokens(current_user.id, db)
        
        return {
            "success": True,
            "message": "Logged out from all devices successfully"
        }
    except Exception as e:
        print(f"❌ Logout-all error: {e}")
        # Still return success
        return {
            "success": True,
            "message": "Logged out from all devices"
        }
>>>>>>> 008fb737f3016194a109b20e536adbcfa8ae3e94


# ================================================
# SECTION 5: VALIDATION HELPERS
# ================================================

@router.get("/check-email", response_model=EmailCheckResponse)
async def check_email(email: str, db: Session = Depends(get_db)):
    """Check if email is available for registration"""
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        return EmailCheckResponse(available=False, message="Email already taken")
    return EmailCheckResponse(available=True, message="Email is available")


@router.get("/check-phone")
async def check_phone(phone_number: str, db: Session = Depends(get_db)):
    """
    Check if phone number is already registered
    """
    try:
        cleaned_phone = clean_phone_number(phone_number)
    except HTTPException:
        return {"available": False, "message": "Invalid phone number format"}
    
    existing_user = db.query(User).filter(User.phone_number == cleaned_phone).first()
    
    if existing_user:
        return {"available": False, "message": "Phone number already registered"}
    
    return {"available": True, "message": "Phone number available"}


# ================================================
# SECTION 6: ROLE MANAGEMENT
# ================================================

@router.get("/roles")
def get_roles(
    current_user: User = Depends(get_current_user),  
    db: Session = Depends(get_db)
):
    """Get all available roles in the system"""
    roles = db.query(Role).all()
    return [
        {
            "id": role.id,
            "role_name": role.role_name,
            "role_description": role.role_description
        }
        for role in roles
    ]


@router.post("/select-role")
def select_role(
    request: RoleSelectRequest,
    current_user: User = Depends(get_current_user),  
    db: Session = Depends(get_db)
):
    """Assign a role to the current user"""
    user_id = current_user.id

    role = db.query(Role).filter(Role.id == request.role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    existing = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role.id
    ).first()

    if existing:
        return {"message": f"Role '{role.role_name}' already assigned to user."}

    user_role = UserRole(user_id=user_id, role_id=role.id)
    db.add(user_role)
    db.commit()
    db.refresh(user_role)

    return {
        "message": f"User '{current_user.full_name}' selected role '{role.role_name}'.",
        "selected_role": {
            "role_id": role.id,
            "role_name": role.role_name
        }
    }


# ================================================
# SECTION 7: USER PROFILE
# ================================================

@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current authenticated user's profile"""
    return current_user