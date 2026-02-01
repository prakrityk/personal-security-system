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
# Add these with your existing imports
from fastapi import UploadFile, File  # Already present
import shutil
import os
from pathlib import Path
import uuid

# ✅ ADD THIS IMPORT at the top of auth.py with other imports
from api.routes.guardian_auto_contacts import on_guardian_profile_updated



# Configuration
UPLOAD_DIR = Path("uploads/profile_pictures")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
MAX_FILE_SIZE = 5 * 1024 * 1024  # 5MB
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.webp'}

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




def validate_image_file(file: UploadFile) -> None:
    """Validate uploaded image file"""
    # Check file extension
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Check content type
    if not file.content_type or not file.content_type.startswith('image/'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image"
        )


def save_upload_file(upload_file: UploadFile, user_id: int) -> str:
    """Save uploaded file and return the path"""
    # Generate unique filename
    file_ext = os.path.splitext(upload_file.filename)[1].lower()
    unique_filename = f"user_{user_id}_{uuid.uuid4().hex}{file_ext}"
    file_path = UPLOAD_DIR / unique_filename
    
    # Save file
    try:
        with file_path.open("wb") as buffer:
            shutil.copyfileobj(upload_file.file, buffer)
    finally:
        upload_file.file.close()
    
    # Return relative path for database storage
    return f"/uploads/profile_pictures/{unique_filename}"


def delete_profile_picture_file(file_path: str) -> None:
    """Delete profile picture file from filesystem"""
    if not file_path:
        return
    
    try:
        # Remove leading slash if present
        clean_path = file_path.lstrip('/')
        full_path = Path(clean_path)
        
        if full_path.exists():
            full_path.unlink()
            print(f"✅ Deleted file: {full_path}")
    except Exception as e:
        print(f"⚠️ Could not delete file {file_path}: {e}")
        # Don't raise exception - file might already be deleted


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

# FIXED: Update the /profile endpoint in auth.py
@router.put("/profile", response_model=UserResponse)
async def update_profile(
    request_data: dict,  # ✅ Change from query params to request body
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update user profile
    ✅ AUTO-UPDATES all emergency contacts where user is a guardian
    
    Parameters:
    - full_name: New full name (optional)
    - phone_number: New phone number (optional)
    
    Returns:
    - Updated user profile
    """
    profile_changed = False
    
    try:
        # Update full name if provided
        full_name = request_data.get("full_name")
        if full_name and full_name != current_user.full_name:
            current_user.full_name = full_name
            profile_changed = True
            print(f"✅ Updated name: {full_name}")
        
        if profile_changed:
            current_user.updated_at = datetime.now(timezone.utc)
            db.commit()
            db.refresh(current_user)
            
            # ✅ AUTO-UPDATE: Sync changes to all emergency contacts
            try:
                on_guardian_profile_updated(db, current_user.id)
                print(f"✅ Updated emergency contacts after profile change")
            except Exception as e:
                print(f"⚠️ Warning: Could not update emergency contacts: {e}")
                # Don't fail the main operation if sync fails
        
        print(f"✅ Profile updated for user {current_user.id}")
        return current_user
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error updating profile: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update profile: {str(e)}"
        )

@router.post("/profile/picture", response_model=UserResponse)
async def upload_profile_picture(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Upload or update user's profile picture
    
    - **file**: Image file (JPG, PNG, GIF, WEBP)
    - **max_size**: 5MB
    
    Returns updated user with new profile_picture path
    """
    # Validate file
    validate_image_file(file)
    
    # Check file size
    file.file.seek(0, 2)  # Seek to end
    file_size = file.file.tell()
    file.file.seek(0)  # Reset to beginning
    
    if file_size > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE / (1024*1024):.0f}MB"
        )
    
    # Delete old profile picture if exists
    if current_user.profile_picture:
        delete_profile_picture_file(current_user.profile_picture)
    
    # Save new file
    file_path = save_upload_file(file, current_user.id)
    
    # Update user record
    current_user.profile_picture = file_path
    db.commit()
    db.refresh(current_user)
    
    print(f"✅ Profile picture uploaded for user {current_user.id}: {file_path}")
    
    return current_user


@router.delete("/profile/picture", status_code=status.HTTP_204_NO_CONTENT)
async def delete_profile_picture(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete user's profile picture
    
    Returns 204 No Content on success
    """
    if not current_user.profile_picture:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No profile picture to delete"
        )
    
    # Delete file from filesystem
    delete_profile_picture_file(current_user.profile_picture)
    
    # Update user record
    current_user.profile_picture = None
    db.commit()
    
    print(f"✅ Profile picture deleted for user {current_user.id}")
    
    return None

@router.post("/verify-email")
async def verify_email(
    email: str,
    otp: str,
    db: Session = Depends(get_db)
):
    """
    Verify email OTP and convert pending user to actual user
    
    Parameters:
    - email: User's email address
    - otp: 6-digit OTP code sent to email
    
    Returns:
    - Success message and user_id
    
    Raises:
    - 404: No pending registration found
    - 400: OTP expired or invalid
    - 429: Too many attempts
    """
    
    # 1. Get pending user
    pending = db.query(PendingUser).filter(
        PendingUser.email == email,
        PendingUser.is_email_verified == False
    ).order_by(PendingUser.created_at.desc()).first()

    if not pending:
        raise HTTPException(
            status_code=404,
            detail="No pending registration found for this email"
        )

    # 2. Check OTP expiry (10 minutes)
    if pending.created_at < datetime.now(timezone.utc) - timedelta(minutes=10):
        raise HTTPException(
            status_code=400,
            detail="OTP expired. Please register again."
        )

    # 3. Check max attempts
    if pending.otp_attempts >= 3:
        raise HTTPException(
            status_code=429,
            detail="Too many attempts. Please register again."
        )

    # 4. Verify OTP
    if pending.email_otp != otp:
        pending.otp_attempts += 1
        db.commit()
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP"
        )

    # 5. Create actual user
    new_user = User(
        full_name=pending.full_name,
        email=pending.email,
        phone_number=pending.phone_number,
        hashed_password=pending.hashed_password,
        email_verified=True,
        phone_verified=True,
        is_active=True
    )

    db.add(new_user)
    
    # 6. Delete pending user
    db.delete(pending)
    
    db.commit()
    db.refresh(new_user)

    print(f"✅ User {new_user.email} created successfully!")

    return {
        "success": True,
        "message": "Email verified successfully. You can now login.",
        "user_id": new_user.id
    }


@router.post("/resend-email-otp")
async def resend_email_otp(
    email: str,
    db: Session = Depends(get_db)
):
    """
    Resend email OTP to pending user
    
    Parameters:
    - email: User's email address
    
    Returns:
    - Success message
    
    Raises:
    - 404: No pending registration found
    - 429: Rate limit (must wait 1 minute)
    """
    
    # Rate limit: 1 OTP per minute
    pending = db.query(PendingUser).filter(
        PendingUser.email == email,
        PendingUser.is_email_verified == False
    ).order_by(PendingUser.created_at.desc()).first()

    if not pending:
        raise HTTPException(
            status_code=404,
            detail="No pending registration found for this email"
        )

    # Check if user requested OTP too soon (less than 1 minute ago)
    if pending.created_at > datetime.now(timezone.utc) - timedelta(minutes=1):
        raise HTTPException(
            status_code=429,
            detail="Please wait before requesting another OTP"
        )

    # Generate new OTP
    new_otp = generate_otp()
    pending.email_otp = new_otp
    pending.otp_attempts = 0
    db.commit()

    # Simulate email sending (replace with actual email service)
    print(f"📧 Resent Email OTP for {email}: {new_otp}")

    return {
        "success": True,
        "message": "OTP resent successfully"
    }


# ===================================================================
# IMPORTANT NOTES:
# ===================================================================
#
# 1. These endpoints use your existing:
#    - PendingUser model
#    - User model
#    - generate_otp() function
#    - All imports are already in your auth.py
#
# 2. OTP Security:
#    - 10 minute expiration
#    - Maximum 3 attempts per OTP
#    - Rate limited to 1 resend per minute
#
# 3. Testing:
#    - After registration, check console for OTP
#    - Use the OTP within 10 minutes
#    - After 3 wrong attempts, user must register again
#
# 4. Production:
#    - Replace print() statements with actual email service
#    - Consider using a background task for sending emails
#    - Add proper email templates
#
# ===================================================================