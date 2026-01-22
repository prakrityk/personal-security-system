"""
Authentication routes
Handles user registration, login, and phone verification
"""

from typing import List, Optional  
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_
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
)

# Models
from models.user import User
from models.role import Role
from models.user_roles import UserRole
from models.otp import OTP

# Auth utilities
from api.dependencies.auth import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user  
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


# ----------------------
# OTP Routes
# ----------------------
@router.post("/send-verification-code")
async def send_verification_code(request: PhoneVerificationRequest, db: Session = Depends(get_db)):
    code = generate_otp()

    otp_entry = OTP(phone_number=request.phone_number, code=code, is_verified=False)
    db.add(otp_entry)
    db.commit()
    db.refresh(otp_entry)

    # For now, print OTP (replace with Twilio later)
    print(f"OTP for {request.phone_number}: {code}")

    return {"success": True, "message": "OTP sent"}


@router.post("/verify-phone")
async def verify_phone(request: PhoneVerificationConfirm, db: Session = Depends(get_db)):
    otp_entry = db.query(OTP).filter(
        OTP.phone_number == request.phone_number,
        OTP.is_verified == False
    ).order_by(OTP.created_at.desc()).first()

    if not otp_entry:
        raise HTTPException(status_code=400, detail="No OTP sent or already verified")

    if otp_entry.code != request.verification_code:
        raise HTTPException(status_code=400, detail="Invalid OTP")

    otp_entry.is_verified = True
    db.commit()

    return {"success": True, "message": "Phone number verified successfully"}


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


# ----------------------
# Registration
# ----------------------
@router.post("/register", response_model=UserWithToken, status_code=status.HTTP_201_CREATED)
async def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """
    Register a new user
    Only allows registration if phone number is verified
    """

    # Check if phone is verified
    otp_verified = db.query(OTP).filter(
        OTP.phone_number == user_data.phone_number,
        OTP.is_verified == True
    ).order_by(OTP.created_at.desc()).first()

    if not otp_verified:
        raise HTTPException(
            status_code=400,
            detail="Phone number not verified. Please verify before registering."
        )

    # Check email uniqueness
    if db.query(User).filter(User.email == user_data.email).first():
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    # Check phone uniqueness
    if db.query(User).filter(User.phone_number == user_data.phone_number).first():
        raise HTTPException(
            status_code=400,
            detail="Phone number already registered"
        )

    # Hash password
    hashed_password = hash_password(user_data.password)

    # Create user
    new_user = User(
        email=user_data.email,
        hashed_password=hashed_password,
        full_name=user_data.full_name,
        phone_number=user_data.phone_number
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # JWT token
    access_token = create_access_token(data={"sub": str(new_user.id), "email": new_user.email})

    user_response = UserResponse(
        id=new_user.id,
        email=new_user.email,
        full_name=new_user.full_name,
        phone_number=new_user.phone_number,
        roles=[]
    )

    token = Token(access_token=access_token, token_type="bearer")

    return UserWithToken(user=user_response, token=token)


# ----------------------
# Login
# ----------------------
@router.post("/login", response_model=UserWithToken)
async def login(login_data: UserLogin, db: Session = Depends(get_db)):
    """
    Login with email or phone number
    """
    user = db.query(User).filter(
        or_(User.email == login_data.email, User.phone_number == login_data.email)
    ).first()

    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    if not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token(data={"sub": str(user.id), "email": user.email})

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

    token = Token(access_token=access_token, token_type="bearer")

    return UserWithToken(user=user_response, token=token)


# ----------------------
# Email check
# ----------------------
@router.get("/check-email", response_model=EmailCheckResponse)
async def check_email(email: str, db: Session = Depends(get_db)):
    existing_user = db.query(User).filter(User.email == email).first()
    if existing_user:
        return EmailCheckResponse(available=False, message="Email already taken")
    return EmailCheckResponse(available=True, message="Email is available")


@router.get("/roles")
def get_roles(
    current_user: User = Depends(get_current_user),  
    db: Session = Depends(get_db)
):
   
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


# ----------------------
# Current user (placeholder)
# ----------------------
@router.get("/me", response_model=UserResponse)
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    return current_user