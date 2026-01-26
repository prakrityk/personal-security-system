"""
Authentication routes
Handles user registration, login, phone verification, and token management
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
    UserWithToken,
    Token,
    EmailCheckResponse,
    PhoneCheckResponse,
    PhoneVerificationRequest,
    PhoneVerificationConfirm,
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

# DB
from database.connection import get_db

# Router
router = APIRouter()


# ----------------------
# OTP Helpers
# ----------------------
def generate_otp() -> str:
    return str(random.randint(100000, 999999))  # 6-digit OTP


# ================================================
# SECTION 1: OTP / PHONE VERIFICATION
# ================================================

@router.post("/send-verification-code")
async def send_verification_code(
    request: PhoneVerificationRequest,
    db: Session = Depends(get_db)
):
    """
    Send OTP verification code to phone number

    Protections:
    - 1 OTP per minute per phone number
    - Maximum 5 OTPs per 24 hours per phone number
    """

    # Rate limit: 1 OTP per minute
    recent_otp = db.query(OTP).filter(
        OTP.phone_number == request.phone_number,
        OTP.created_at > func.now() - timedelta(minutes=1)
    ).first()

    if recent_otp:
        raise HTTPException(
            status_code=429,
            detail="Please wait before requesting another OTP"
        )

    # Daily limit: max 5 OTPs in last 24 hours
    today_count = db.query(OTP).filter(
        OTP.phone_number == request.phone_number,
        OTP.created_at > func.now() - timedelta(hours=24)
    ).count()

    if today_count >= 5:
        raise HTTPException(
            status_code=429,
            detail="OTP limit reached for today"
        )

    # Generate and store OTP
    code = generate_otp()

    otp_entry = OTP(
        phone_number=request.phone_number,
        code=code,
        attempts=0,
        is_verified=False
    )

    db.add(otp_entry)
    db.commit()
    db.refresh(otp_entry)

    # Replace with SMS provider integration
    print(f"OTP for {request.phone_number}: {code}")

    return {
        "success": True,
        "message": "OTP sent"
    }




from datetime import timedelta
from sqlalchemy.sql import func

@router.post("/verify-phone")
async def verify_phone(
    request: PhoneVerificationConfirm,
    db: Session = Depends(get_db)
):
    """
    Verify OTP for phone number
    """

    #Get latest unverified OTP for this phone number
    otp = db.query(OTP).filter(
        OTP.phone_number == request.phone_number,
        OTP.is_verified == False
    ).order_by(OTP.created_at.desc()).first()

    if not otp:
        raise HTTPException(
            status_code=400,
            detail="Invalid or already used OTP"
        )

    # Expiry check (5 minutes)
    if otp.created_at < datetime.now(timezone.utc) - timedelta(minutes=5):

        raise HTTPException(
            status_code=400,
            detail="OTP expired"
        )

    # Max attempts
    if otp.attempts >= 3:
        raise HTTPException(
            status_code=429,
            detail="Too many attempts. Request new OTP."
        )

    # Wrong code
    if otp.code != request.verification_code:
        otp.attempts += 1
        db.commit()
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP"
        )

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


# ================================================
# SECTION 3: LOGIN
# ================================================

@router.post("/login", response_model=UserWithTokens)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """
    Login with email or phone number
    Returns user profile with access token and refresh token
    """
    user = db.query(User).filter(
        or_(User.email == login_data.email, User.phone_number == login_data.email)
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
    # Verify refresh token
    refresh_token = verify_refresh_token(request.refresh_token, db)
    
    if not refresh_token:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired refresh token"
        )
    
    # Get user
    user = db.query(User).filter(User.id == refresh_token.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Create new access token
    access_token = create_access_token(data={"sub": str(user.id), "email": user.email})
    
    # Rotate refresh token (create new one and revoke old)
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


@router.post("/logout-all")
async def logout_all_devices(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
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


# ================================================
# SECTION 5: VALIDATION HELPERS
# ================================================

@router.get("/check-email", response_model=EmailCheckResponse)
async def check_email(email: str, db: Session = Depends(get_db)):
    """
    Check if email is available for registration
    """
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        return EmailCheckResponse(available=False, message="Email already taken")
    return EmailCheckResponse(available=True, message="Email is available")


# ================================================
# SECTION 6: ROLE MANAGEMENT
# ================================================

@router.get("/roles")
def get_roles(
    current_user: User = Depends(get_current_user),  
    db: Session = Depends(get_db)
):
    """
    Get all available roles in the system
    Requires authentication
    """
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
    """
    Assign a role to the current user
    Users can have multiple roles (e.g., global_user + guardian)
    """
    user_id = current_user.id

    role = db.query(Role).filter(Role.id == request.role_id).first()
    if not role:
        raise HTTPException(status_code=404, detail="Role not found")
    
    # Check if user already has this role
    existing = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role.id
    ).first()

    if existing:
        return {"message": f"Role '{role.role_name}' already assigned to user."}

    # Assign role
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
    """
    Get current authenticated user's profile
    """
    return current_user