"""
Authentication Routes - Firebase Integration (FIXED)
Handles user registration and login with Firebase verification
CHANGES: Made endpoint async and added timeout handling
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import asyncio
import logging

from database.connection import get_db
from models.user import User
from models.role import Role
from models.user_roles import UserRole
from api.schemas.auth import (
    FirebaseTokenVerification,
    FirebaseRegistrationComplete,
    UserLogin,
    UserResponse,
    UserWithTokens,
    TokenResponse,
    RefreshTokenRequest,
    EmailCheckResponse,
    PhoneCheckResponse,
    RoleSelectRequest,
    RoleInfo
)
from services.firebase_service import firebase_service
from api.utils.auth_utils import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    verify_refresh_token,
    get_current_user
)
from models.refresh_token import RefreshToken
from datetime import datetime, timedelta

router = APIRouter()
logger = logging.getLogger(__name__)


# =====================================================
# FIREBASE REGISTRATION FLOW
# =====================================================

@router.post("/firebase/verify-token", status_code=status.HTTP_200_OK)
async def verify_firebase_token(
    request: FirebaseTokenVerification,
    db: Session = Depends(get_db)
):
    """
    Step 1: Verify Firebase token after phone + email verification
    
    Flow:
    1. User completes phone verification in Flutter (Firebase)
    2. User completes email verification in Flutter (Firebase)
    3. Flutter sends Firebase ID token to this endpoint
    4. Backend verifies token and extracts user info
    5. Returns verification status
    
    This endpoint checks if user already exists or needs to complete registration
    """
    try:
        # Run Firebase verification in thread pool to avoid blocking
        firebase_user = await asyncio.to_thread(
            firebase_service.verify_firebase_token,
            request.firebase_token
        )
        
        logger.info(f"✅ Firebase token verified for user: {firebase_user.get('uid')}")
        
    except Exception as e:
        logger.error(f"❌ Firebase token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Firebase verification failed: {str(e)}"
        )
    
    # Check both email and phone are verified
    if not firebase_user['email_verified']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified in Firebase. Please verify your email first."
        )
    
    if not firebase_user['phone_verified']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number not verified in Firebase. Please verify your phone first."
        )
    
    # Check if user already exists in our database
    existing_user = db.query(User).filter(
        User.firebase_uid == firebase_user['uid']
    ).first()
    
    if existing_user:
        return {
            "success": True,
            "message": "User already registered",
            "user_exists": True,
            "firebase_uid": firebase_user['uid'],
            "email": firebase_user['email'],
            "phone_number": firebase_user['phone_number']
        }
    
    # User verified in Firebase but not in our database
    return {
        "success": True,
        "message": "Firebase verification successful. Complete registration.",
        "user_exists": False,
        "firebase_uid": firebase_user['uid'],
        "email": firebase_user['email'],
        "phone_number": firebase_user['phone_number'],
        "email_verified": True,
        "phone_verified": True
    }


@router.post("/firebase/complete-registration", response_model=UserWithTokens, status_code=status.HTTP_201_CREATED)
async def complete_firebase_registration(
    request: FirebaseRegistrationComplete,
    db: Session = Depends(get_db)
):
    """
    Complete registration with Firebase-verified credentials
    
    Request body:
    {
        "firebase_token": "eyJhbGc...",
        "full_name": "John Doe",
        "password": "SecurePass123!"
    }
    
    Flow:
    1. Verify Firebase token (async/non-blocking)
    2. Extract email and phone from Firebase
    3. Create user in database with verified status
    4. Return JWT tokens
    """
    try:
        logger.info("📝 Starting Firebase registration...")
        
        # Verify Firebase token in thread pool (non-blocking)
        firebase_user = await asyncio.to_thread(
            firebase_service.verify_firebase_token,
            request.firebase_token
        )
        
        logger.info(f"✅ Firebase token verified - UID: {firebase_user.get('uid')}")
        
    except Exception as e:
        logger.error(f"❌ Firebase token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Firebase verification failed: {str(e)}"
        )
    
    # Verify both email and phone are verified
    if not firebase_user['email_verified']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified"
        )
    
    if not firebase_user['phone_verified']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number not verified"
        )
    
    # Check if user already exists
    existing_user = db.query(User).filter(
        User.firebase_uid == firebase_user['uid']
    ).first()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already registered with this Firebase account"
        )
    
    try:
        # Hash password
        logger.info("🔐 Hashing password...")
        hashed_pw = hash_password(request.password)
        
        # Create new user
        logger.info("👤 Creating user in database...")
        new_user = User(
            firebase_uid=firebase_user['uid'],
            email=firebase_user['email'],
            phone_number=firebase_user['phone_number'],
            full_name=request.full_name,
            hashed_password=hashed_pw,
            email_verified=True,  # Already verified by Firebase
            phone_verified=True,  # Already verified by Firebase
            is_active=True
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        logger.info(f"✅ User created - ID: {new_user.id}")
        
        # Create JWT tokens
        logger.info("🎫 Generating JWT tokens...")
        access_token = create_access_token(data={"sub": str(new_user.id)})
        refresh_token_str = create_refresh_token(data={"sub": str(new_user.id)})
        
        # Store refresh token in database
        logger.info("💾 Storing refresh token...")
        refresh_token_record = RefreshToken(
            user_id=new_user.id,
            token=refresh_token_str,
            expires_at=datetime.utcnow() + timedelta(days=30)
        )
        db.add(refresh_token_record)
        db.commit()
        logger.info("✅ Tokens created and stored")
        
        # Prepare response
        user_response = UserResponse(
            id=new_user.id,
            email=new_user.email,
            full_name=new_user.full_name,
            phone_number=new_user.phone_number,
            roles=[]  # No roles yet - user will select after registration
        )
        
        tokens = TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token_str,
            token_type="bearer",
            expires_in=1800  # 30 minutes
        )
        
        logger.info("✅ Firebase registration completed successfully!")
        return UserWithTokens(user=user_response, tokens=tokens)
        
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Error during registration: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


# =====================================================
# TRADITIONAL LOGIN (Email/Password)
# =====================================================

@router.post("/login", response_model=UserWithTokens)
def login(
    credentials: UserLogin,
    db: Session = Depends(get_db)
):
    """
    Login with email and password (traditional auth)
    
    After Firebase registration, users log in daily with email + password
    Firebase is only used during registration for verification
    """
    # Find user by email or phone
    user = db.query(User).filter(
        (User.email == credentials.email) | (User.phone_number == credentials.email)
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email/phone or password"
        )
    
    # Verify password
    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email/phone or password"
        )
    
    # Check if user is active
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    # Create tokens
    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token_str = create_refresh_token(data={"sub": str(user.id)})
    
    # Store refresh token
    refresh_token_record = RefreshToken(
        user_id=user.id,
        token=refresh_token_str,
        expires_at=datetime.utcnow() + timedelta(days=30)
    )
    db.add(refresh_token_record)
    db.commit()
    
    # Get user roles
    user_roles = [
        RoleInfo(
            id=ur.role.id,
            role_name=ur.role.role_name,
            role_description=ur.role.role_description
        )
        for ur in user.user_roles
    ]
    
    user_response = UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        phone_number=user.phone_number,
        roles=user_roles
    )
    
    tokens = TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_str,
        token_type="bearer",
        expires_in=1800
    )
    
    return UserWithTokens(user=user_response, tokens=tokens)


# =====================================================
# REFRESH TOKEN
# =====================================================

@router.post("/refresh", response_model=TokenResponse)
def refresh_access_token(
    request: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    """
    Refresh access token using refresh token
    """
    # Verify refresh token
    user_id = verify_refresh_token(request.refresh_token)
    
    # Check if user exists
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )
    
    # Check if refresh token exists in database and is valid
    token_record = db.query(RefreshToken).filter(
        RefreshToken.user_id == user_id,
        RefreshToken.is_revoked == False,
        RefreshToken.expires_at > datetime.utcnow()
    ).first()
    
    if not token_record:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    # Create new access token
    access_token = create_access_token(data={"sub": str(user_id)})
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=request.refresh_token,  # Keep same refresh token
        token_type="bearer",
        expires_in=1800
    )


# =====================================================
# AVAILABILITY CHECKS
# =====================================================

@router.get("/check-email/{email}", response_model=EmailCheckResponse)
def check_email_availability(email: str, db: Session = Depends(get_db)):
    """Check if email is available for registration"""
    existing = db.query(User).filter(User.email == email).first()
    
    if existing:
        return EmailCheckResponse(
            available=False,
            message="Email already registered"
        )
    
    return EmailCheckResponse(
        available=True,
        message="Email available"
    )


@router.get("/check-phone/{phone_number}", response_model=PhoneCheckResponse)
def check_phone_availability(phone_number: str, db: Session = Depends(get_db)):
    """Check if phone number is available for registration"""
    existing = db.query(User).filter(User.phone_number == phone_number).first()
    
    if existing:
        return PhoneCheckResponse(
            available=False,
            message="Phone number already registered"
        )
    
    return PhoneCheckResponse(
        available=True,
        message="Phone number available"
    )


# =====================================================
# USER PROFILE
# =====================================================

@router.get("/me", response_model=UserResponse)
def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """Get current authenticated user information"""
    user_roles = [
        RoleInfo(
            id=ur.role.id,
            role_name=ur.role.role_name,
            role_description=ur.role.role_description
        )
        for ur in current_user.user_roles
    ]
    
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        phone_number=current_user.phone_number,
        roles=user_roles
    )


# =====================================================
# ROLE SELECTION (After Registration)
# =====================================================

@router.post("/select-role", response_model=UserResponse)
def select_user_role(
    request: RoleSelectRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Allow user to select their role after registration
    (global_user, guardian, child, elderly)
    """
    # Check if role exists
    role = db.query(Role).filter(Role.id == request.role_id).first()
    if not role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found"
        )
    
    # Don't allow selecting 'admin' role
    if role.role_name == "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot self-assign admin role"
        )
    
    # Check if user already has this role
    existing_role = db.query(UserRole).filter(
        UserRole.user_id == current_user.id,
        UserRole.role_id == request.role_id
    ).first()
    
    if existing_role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already has this role"
        )
    
    # Assign role
    user_role = UserRole(
        user_id=current_user.id,
        role_id=request.role_id
    )
    db.add(user_role)
    db.commit()
    
    # Refresh user to get updated roles
    db.refresh(current_user)
    
    user_roles = [
        RoleInfo(
            id=ur.role.id,
            role_name=ur.role.role_name,
            role_description=ur.role.role_description
        )
        for ur in current_user.user_roles
    ]
    
    return UserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        phone_number=current_user.phone_number,
        roles=user_roles
    )


@router.get("/roles", response_model=List[RoleInfo])
def get_available_roles(db: Session = Depends(get_db)):
    """Get list of available roles for selection (excluding admin)"""
    roles = db.query(Role).filter(Role.role_name != "admin").all()
    
    return [
        RoleInfo(
            id=role.id,
            role_name=role.role_name,
            role_description=role.role_description
        )
        for role in roles
    ]


# =====================================================
# TEST ENDPOINT (REMOVE IN PRODUCTION)
# =====================================================

@router.post("/test/register-without-firebase", response_model=UserWithTokens, status_code=status.HTTP_201_CREATED)
def test_register_without_firebase(
    email: str,
    phone_number: str,
    full_name: str,
    password: str,
    db: Session = Depends(get_db)
):
    """
    TEMPORARY TEST ENDPOINT - Remove in production!
    Register user without Firebase verification (for testing backend only)
    """
    # Check if user exists
    existing_email = db.query(User).filter(User.email == email).first()
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    existing_phone = db.query(User).filter(User.phone_number == phone_number).first()
    if existing_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered"
        )
    
    # Hash password
    hashed_pw = hash_password(password)
    
    # Create test firebase_uid
    import uuid
    test_firebase_uid = f"test_{uuid.uuid4().hex[:20]}"
    
    # Create new user
    new_user = User(
        firebase_uid=test_firebase_uid,
        email=email,
        phone_number=phone_number,
        full_name=full_name,
        hashed_password=hashed_pw,
        email_verified=True,
        phone_verified=True,
        is_active=True
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Create JWT tokens
    access_token = create_access_token(data={"sub": str(new_user.id)})
    refresh_token_str = create_refresh_token(data={"sub": str(new_user.id)})
    
    # Store refresh token in database
    refresh_token_record = RefreshToken(
        user_id=new_user.id,
        token=refresh_token_str,
        expires_at=datetime.utcnow() + timedelta(days=30)
    )
    db.add(refresh_token_record)
    db.commit()
    
    # Prepare response
    user_response = UserResponse(
        id=new_user.id,
        email=new_user.email,
        full_name=new_user.full_name,
        phone_number=new_user.phone_number,
        roles=[]
    )
    
    tokens = TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_str,
        token_type="bearer",
        expires_in=1800
    )
    
    return UserWithTokens(user=user_response, tokens=tokens)