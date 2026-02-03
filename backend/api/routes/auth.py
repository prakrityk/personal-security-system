"""
Authentication Routes - Firebase Integration (WITH DETAILED LOGGING)
Handles user registration and login with Firebase verification
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
    FirebaseLoginRequest,
    UserLogin,
    UserResponse,
    UserWithTokens,
    TokenResponse,
    RefreshTokenRequest,
    EmailCheckResponse,
    PhoneCheckResponse,
    RoleSelectRequest,
    RoleInfo,
    PasswordUpdateRequest,
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
    """
    try:
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
    """Complete registration with Firebase-verified credentials"""
    
    # ============================================================================
    # DETAILED LOGGING - CHECK TOKEN RECEIPT
    # ============================================================================
    logger.info("="*80)
    logger.info("📝 FIREBASE REGISTRATION REQUEST RECEIVED")
    logger.info("="*80)
    
    logger.info(f"📦 Request Data:")
    logger.info(f"   Full Name: {request.full_name}")
    logger.info(f"   Password: {'*' * len(request.password)} (length: {len(request.password)})")
    
    # Check if token exists
    if not request.firebase_token:
        logger.error("❌ NO TOKEN RECEIVED FROM CLIENT!")
        logger.error("   request.firebase_token is None or empty")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Firebase token is required but was not provided"
        )
    
    # Log token details
    token_length = len(request.firebase_token)
    logger.info(f"🔑 Firebase Token:")
    logger.info(f"   Token received: YES ✓")
    logger.info(f"   Token length: {token_length} characters")
    logger.info(f"   Token preview (first 100 chars): {request.firebase_token[:100]}...")
    logger.info(f"   Token preview (last 50 chars): ...{request.firebase_token[-50:]}")
    
    # Check token format
    if not request.firebase_token.startswith('eyJ'):
        logger.error(f"❌ INVALID TOKEN FORMAT!")
        logger.error(f"   Expected JWT starting with 'eyJ'")
        logger.error(f"   Got: {request.firebase_token[:20]}...")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid token format"
        )
    
    logger.info(f"✅ Token format looks valid (JWT)")
    logger.info(f"🔄 Attempting Firebase verification...")
    logger.info("="*80)
    
    # ============================================================================
    # FIREBASE VERIFICATION
    # ============================================================================
    try:
        firebase_user = await asyncio.to_thread(
            firebase_service.verify_firebase_token,
            request.firebase_token
        )
        
        logger.info("="*80)
        logger.info(f"✅ FIREBASE TOKEN VERIFIED SUCCESSFULLY")
        logger.info("="*80)
        logger.info(f"📋 Extracted User Info:")
        logger.info(f"   UID: {firebase_user.get('uid')}")
        logger.info(f"   Email: {firebase_user.get('email')}")
        logger.info(f"   Phone: {firebase_user.get('phone_number')}")
        logger.info(f"   Email Verified: {firebase_user.get('email_verified')}")
        logger.info(f"   Phone Verified: {firebase_user.get('phone_verified')}")
        logger.info("="*80)
        
    except HTTPException as e:
        logger.error("="*80)
        logger.error(f"❌ FIREBASE VERIFICATION FAILED (HTTPException)")
        logger.error("="*80)
        logger.error(f"   Status Code: {e.status_code}")
        logger.error(f"   Detail: {e.detail}")
        logger.error("="*80)
        raise
        
    except Exception as e:
        logger.error("="*80)
        logger.error(f"❌ FIREBASE VERIFICATION FAILED (Unexpected Error)")
        logger.error("="*80)
        logger.error(f"   Error Type: {type(e).__name__}")
        logger.error(f"   Error Message: {str(e)}")
        logger.error("="*80)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Firebase verification failed: {str(e)}"
        )
    
    # Verify both email and phone are verified
    if not firebase_user['email_verified']:
        logger.error("❌ Email not verified in Firebase")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not verified"
        )
    
    if not firebase_user['phone_verified']:
        logger.error("❌ Phone not verified in Firebase")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number not verified"
        )
    
    # Check if user already exists
    existing_user = db.query(User).filter(
        User.firebase_uid == firebase_user['uid']
    ).first()
    
    if existing_user:
        logger.warning(f"⚠️ User already exists with Firebase UID: {firebase_user['uid']}")
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
            email_verified=True,
            phone_verified=True,
            is_active=True
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        logger.info(f"✅ User created successfully with ID: {new_user.id}")
        
        # Create JWT tokens
        logger.info("🔑 Generating JWT tokens...")
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
        
        logger.info("="*80)
        logger.info("✅ REGISTRATION COMPLETE!")
        logger.info("="*80)
        
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
        
    except Exception as e:
        logger.error("="*80)
        logger.error(f"❌ DATABASE ERROR DURING REGISTRATION")
        logger.error("="*80)
        logger.error(f"   Error Type: {type(e).__name__}")
        logger.error(f"   Error Message: {str(e)}")
        logger.error("="*80)
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Registration failed: {str(e)}"
        )


# =====================================================
# 🔥 FIREBASE LOGIN (for after password reset)
# =====================================================

@router.post("/firebase/login", response_model=UserWithTokens)
async def firebase_login(
    request: FirebaseLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Login via Firebase token + sync new password into DB.
    
    Called when normal /login fails after a Firebase password reset.
    Flutter signs into Firebase with the new password, gets a Firebase ID token,
    and sends it here along with the new password.
    
    This endpoint:
      1. Verifies the Firebase token (proves identity)
      2. Finds the user by firebase_uid
      3. Re-hashes and updates hashed_password in DB (syncs the reset password)
      4. Issues fresh JWT tokens
    """
    logger.info("="*80)
    logger.info("🔥 FIREBASE LOGIN REQUEST")
    logger.info("="*80)

    # ============================================================================
    # VERIFY FIREBASE TOKEN
    # ============================================================================
    try:
        firebase_user = await asyncio.to_thread(
            firebase_service.verify_firebase_token,
            request.firebase_token
        )
        logger.info(f"✅ Firebase token verified for UID: {firebase_user.get('uid')}")
    except Exception as e:
        logger.error(f"❌ Firebase login: token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase verification failed"
        )

    # ============================================================================
    # FIND USER BY firebase_uid
    # ============================================================================
    user = db.query(User).filter(
        User.firebase_uid == firebase_user['uid']
    ).first()

    if not user:
        logger.error(f"❌ Firebase login: no user found for UID {firebase_user['uid']}")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )

    # ============================================================================
    # SYNC PASSWORD — update hashed_password so normal login works next time
    # ============================================================================
    logger.info(f"🔐 Syncing new password for user {user.id}...")
    user.hashed_password = hash_password(request.password)
    db.commit()
    logger.info(f"✅ Password synced for user {user.id}")

    # ============================================================================
    # ISSUE JWT TOKENS
    # ============================================================================
    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token_str = create_refresh_token(data={"sub": str(user.id)})

    refresh_token_record = RefreshToken(
        user_id=user.id,
        token=refresh_token_str,
        expires_at=datetime.utcnow() + timedelta(days=30)
    )
    db.add(refresh_token_record)
    db.commit()

    user_roles = [
        RoleInfo(
            id=ur.role.id,
            role_name=ur.role.role_name,
            role_description=ur.role.role_description
        )
        for ur in user.user_roles
    ]

    logger.info("="*80)
    logger.info(f"✅ FIREBASE LOGIN COMPLETE for user {user.id}")
    logger.info("="*80)

    return UserWithTokens(
        user=UserResponse(
            id=user.id,
            email=user.email,
            full_name=user.full_name,
            phone_number=user.phone_number,
            roles=user_roles
        ),
        tokens=TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token_str,
            token_type="bearer",
            expires_in=1800
        )
    )


# =====================================================
# 🔐 PASSWORD UPDATE (for forgot-password sync)
# =====================================================

@router.put("/update-password")
def update_password(
    request: PasswordUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update hashed_password in DB after Firebase password reset.
    Protected — requires valid access token (user must be logged in).
    Called from Flutter after user logs in with their new password.
    """
    logger.info(f"🔐 Password update request for user {current_user.id}")

    hashed_pw = hash_password(request.password)
    current_user.hashed_password = hashed_pw
    db.commit()

    logger.info(f"✅ Password updated for user {current_user.id}")

    return {"success": True, "message": "Password updated successfully"}

# =====================================================
# TRADITIONAL LOGIN (PASSWORD-BASED)
# =====================================================

@router.post("/login", response_model=UserWithTokens)
def login_user(
    request: UserLogin,
    db: Session = Depends(get_db)
):
    """Login user with email/phone and password"""
    user = db.query(User).filter(
       
        (User.phone_number == request.phone_number)
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    
    if not verify_password(request.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token_str = create_refresh_token(data={"sub": str(user.id)})
    
    refresh_token_record = RefreshToken(
        user_id=user.id,
        token=refresh_token_str,
        expires_at=datetime.utcnow() + timedelta(days=30)
    )
    db.add(refresh_token_record)
    db.commit()
    
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


@router.post("/refresh", response_model=TokenResponse)
def refresh_access_token(
    request: RefreshTokenRequest,
    db: Session = Depends(get_db)
):
    """Refresh access token using refresh token"""
    try:
        payload = verify_refresh_token(request.refresh_token)
    except:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    refresh_token = db.query(RefreshToken).filter(
        RefreshToken.token == request.refresh_token,
        RefreshToken.user_id == int(user_id),
        RefreshToken.expires_at > datetime.utcnow(),
        RefreshToken.is_revoked == False
    ).first()
    
    if not refresh_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )
    
    access_token = create_access_token(data={"sub": str(user_id)})
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=request.refresh_token,
        token_type="bearer",
        expires_in=1800
    )


@router.get("/check-email/{email}", response_model=EmailCheckResponse)
def check_email_availability(email: str, db: Session = Depends(get_db)):
    """Check if email is available"""
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
    """Check if phone number is available"""
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


@router.get("/me", response_model=UserResponse)
def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """Get current user information"""
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
# 🔐 BIOMETRIC & ROLE ASSIGNMENT (MODIFIED)
# =====================================================

@router.post("/select-role", response_model=dict)
def select_user_role(
    request: RoleSelectRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Select user role after registration.
    
    IMPORTANT: For Guardian role, this endpoint does NOT assign the role immediately.
    Instead, it requires biometric setup first. The role will be assigned when
    the user calls /enable-biometric endpoint.
    """
    logger.info(f"📋 Role selection requested by user {current_user.id} for role_id {request.role_id}")
    
    # Get the role
    role = db.query(Role).filter(Role.id == request.role_id).first()
    if not role:
        logger.error(f"❌ Role {request.role_id} not found")
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Role not found"
        )
    
    logger.info(f"   Role name: {role.role_name}")
    
    # Prevent self-assignment of admin role
    if role.role_name == "admin":
        logger.error(f"❌ User attempted to self-assign admin role")
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
        logger.warning(f"⚠️ User already has role {role.role_name}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User already has this role"
        )
    
    # ============================================================================
    # GUARDIAN ROLE - REQUIRE BIOMETRIC FIRST (DO NOT ASSIGN YET)
    # ============================================================================
    if role.role_name.lower() == "guardian":
        logger.info(f"🔐 Guardian role selected - biometric authentication required")
        logger.info(f"   Role will NOT be assigned until biometric is enabled")
        
        return {
            "success": True,
            "message": "Guardian role selected. Please enable biometric authentication to complete setup.",
            "biometric_required": True,
            "role_assigned": False,
            "role_name": role.role_name
        }
    
    # ============================================================================
    # OTHER ROLES - ASSIGN IMMEDIATELY (Personal, Dependent, etc.)
    # ============================================================================
    logger.info(f"✅ Non-guardian role - assigning immediately")
    
    user_role = UserRole(
        user_id=current_user.id,
        role_id=request.role_id
    )
    db.add(user_role)
    db.commit()
    
    logger.info(f"✅ Role {role.role_name} assigned successfully to user {current_user.id}")
    
    db.refresh(current_user)
    
    user_roles = [
        RoleInfo(
            id=ur.role.id,
            role_name=ur.role.role_name,
            role_description=ur.role.role_description
        )
        for ur in current_user.user_roles
    ]
    
    return {
        "success": True,
        "message": f"Role {role.role_name} assigned successfully",
        "biometric_required": False,
        "role_assigned": True,
        "user": UserResponse(
            id=current_user.id,
            email=current_user.email,
            full_name=current_user.full_name,
            phone_number=current_user.phone_number,
            roles=user_roles
        )
    }


@router.post("/enable-biometric", response_model=UserResponse)
def enable_biometric_authentication(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Enable biometric authentication for the current user.
    
    For Guardian users: This also assigns the Guardian role if not already assigned.
    This ensures Guardian role is only granted AFTER biometric setup is complete.
    """
    logger.info("="*80)
    logger.info(f"🔐 BIOMETRIC ENABLE REQUEST")
    logger.info("="*80)
    logger.info(f"   User ID: {current_user.id}")
    logger.info(f"   Email: {current_user.email}")
    logger.info(f"   Current biometric status: {current_user.biometric_enabled}")
    
    # Check if biometric is already enabled
    if current_user.biometric_enabled:
        logger.warning(f"⚠️ Biometric already enabled for user {current_user.id}")
        # Don't raise error, just return success
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
    
    # Enable biometric
    logger.info(f"✅ Enabling biometric for user {current_user.id}")
    current_user.biometric_enabled = True
    
    # ============================================================================
    # ASSIGN GUARDIAN ROLE IF NOT ALREADY ASSIGNED
    # ============================================================================
    guardian_role = db.query(Role).filter(Role.role_name.ilike("guardian")).first()
    
    if guardian_role:
        logger.info(f"   Guardian role found (ID: {guardian_role.id})")
        
        # Check if user already has guardian role
        has_guardian_role = db.query(UserRole).filter(
            UserRole.user_id == current_user.id,
            UserRole.role_id == guardian_role.id
        ).first()
        
        if not has_guardian_role:
            logger.info(f"   User does NOT have guardian role yet - assigning now")
            
            # Assign guardian role
            user_role = UserRole(
                user_id=current_user.id,
                role_id=guardian_role.id
            )
            db.add(user_role)
            logger.info(f"✅ Guardian role assigned to user {current_user.id}")
        else:
            logger.info(f"   User already has guardian role")
    else:
        logger.warning(f"⚠️ Guardian role not found in database")
    
    # Commit all changes
    db.commit()
    db.refresh(current_user)
    
    logger.info("="*80)
    logger.info(f"✅ BIOMETRIC ENABLED SUCCESSFULLY")
    logger.info("="*80)
    
    # Prepare response
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


@router.post("/disable-biometric")
def disable_biometric_authentication(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disable biometric authentication for the current user"""
    logger.info(f"🔓 Disabling biometric for user {current_user.id}")
    
    current_user.biometric_enabled = False
    db.commit()
    
    logger.info(f"✅ Biometric disabled for user {current_user.id}")
    
    return {
        "success": True,
        "message": "Biometric authentication disabled successfully"
    }


@router.get("/roles", response_model=List[RoleInfo])
def get_available_roles(db: Session = Depends(get_db)):
    """Get list of available roles"""
    roles = db.query(Role).filter(Role.role_name != "admin").all()
    
    return [
        RoleInfo(
            id=role.id,
            role_name=role.role_name,
            role_description=role.role_description
        )
        for role in roles
    ]

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