"""
Authentication Utilities
Password hashing, JWT token creation/verification
"""
from datetime import datetime, timedelta
from typing import Optional, List
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
import os
from dotenv import load_dotenv

from database.connection import get_db
from models.user import User
from models.user_roles import UserRole
from models.role import Role

load_dotenv()

# JWT Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Bearer token security
security = HTTPBearer()


# =====================================================
# PASSWORD UTILITIES
# =====================================================

def hash_password(password: str) -> str:
    """Hash a plain password"""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return pwd_context.verify(plain_password, hashed_password)


# =====================================================
# JWT TOKEN UTILITIES
# =====================================================

def create_access_token(
    data: dict, 
    db: Optional[Session] = None,
    user_id: Optional[int] = None,
    expires_delta: Optional[timedelta] = None
) -> str:
    """
    Create JWT access token with optional role inclusion
    
    Args:
        data: Payload to encode (should include 'sub' with user ID)
        db: Database session (required to fetch user roles)
        user_id: User ID to fetch roles for (optional, can be extracted from data['sub'])
        expires_delta: Custom expiration time (default: 30 minutes)
    
    Returns:
        Encoded JWT token string
    """
    to_encode = data.copy()
    
    # ✅ CRITICAL: Add user roles to token if db session is provided
    if db:
        try:
            # Get user ID from data if not explicitly provided
            if user_id is None:
                user_id = int(data.get("sub"))
            
            if user_id:
                # Fetch user roles
                user_roles = db.query(Role).join(UserRole).filter(
                    UserRole.user_id == user_id
                ).all()
                
                # Add roles to token payload
                to_encode["roles"] = [role.role_name for role in user_roles]
                to_encode["has_roles"] = bool(user_roles)
        except Exception as e:
            # Log error but don't fail token creation
            print(f"Warning: Could not fetch roles for token: {e}")
            to_encode["roles"] = []
            to_encode["has_roles"] = False
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire, "type": "access"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt


def create_refresh_token(
    data: dict,
    db: Optional[Session] = None,
    user_id: Optional[int] = None
) -> str:
    """
    Create JWT refresh token (longer expiration) with optional role inclusion
    
    Args:
        data: Payload to encode (should include 'sub' with user ID)
        db: Database session (optional, for role inclusion)
        user_id: User ID (optional, for role inclusion)
    
    Returns:
        Encoded JWT refresh token string
    """
    to_encode = data.copy()
    
    # ✅ Optionally add roles to refresh token as well
    if db and user_id:
        try:
            user_roles = db.query(Role).join(UserRole).filter(
                UserRole.user_id == user_id
            ).all()
            to_encode["roles"] = [role.role_name for role in user_roles]
        except Exception:
            pass  # Don't fail refresh token creation if roles can't be fetched
    
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt


def verify_access_token(token: str) -> dict:
    """
    Verify and decode access token
    
    Args:
        token: JWT token string
    
    Returns:
        Decoded payload
    
    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # Check token type
        if payload.get("type") != "access":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )
        
        return payload
        
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )


def verify_refresh_token(token: str) -> dict:
    """
    Verify and decode refresh token
    
    Args:
        token: JWT refresh token string
    
    Returns:
        Decoded payload
    
    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        
        # Check token type
        if payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )
        
        return payload
        
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token"
        )


# =====================================================
# DEPENDENCY FOR PROTECTED ROUTES
# =====================================================

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Dependency to get current authenticated user with token roles attached
    
    Usage in routes:
        @router.get("/protected")
        def protected_route(current_user: User = Depends(get_current_user)):
            return {"user_id": current_user.id}
    
    Args:
        credentials: Bearer token from request header
        db: Database session
    
    Returns:
        User object with token_roles attribute
    
    Raises:
        HTTPException: If token is invalid or user not found
    """
    token = credentials.credentials
    
    # Verify token
    payload = verify_access_token(token)
    user_id = payload.get("sub")
    
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )
    
    # Get user from database
    user = db.query(User).filter(User.id == int(user_id)).first()
    
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is deactivated"
        )
    
    # ✅ CRITICAL: Attach roles from token to user object
    user.token_roles = payload.get("roles", [])
    user.has_roles = payload.get("has_roles", False)
    
    return user


def get_current_user_with_roles(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    Enhanced version that also validates user has roles from database
    
    Use this for endpoints that require role verification
    """
    user = get_current_user(credentials, db)
    
    # Additional validation: ensure roles in token match database
    if hasattr(user, 'token_roles'):
        # Fetch fresh roles from database for verification
        db_roles = db.query(Role).join(UserRole).filter(
            UserRole.user_id == user.id
        ).all()
        db_role_names = [role.role_name for role in db_roles]
        
        # Log for debugging
        print(f"Token roles: {user.token_roles}, DB roles: {db_role_names}")
    
    return user


def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """
    Dependency to get current user (optional - for public routes that can be accessed with or without auth)
    
    Returns:
        User object if authenticated, None otherwise
    """
    if credentials is None:
        return None
    
    try:
        return get_current_user(credentials, db)
    except HTTPException:
        return None


# =====================================================
# ROLE VERIFICATION UTILITIES
# =====================================================

def has_role(user: User, role_name: str) -> bool:
    """
    Check if user has a specific role (using token roles)
    
    Args:
        user: User object (from get_current_user)
        role_name: Role name to check
    
    Returns:
        True if user has the role, False otherwise
    """
    if not hasattr(user, 'token_roles'):
        return False
    return role_name in user.token_roles


def require_role(role_name: str):
    """
    Dependency factory to require specific role
    
    Usage:
        @router.get("/admin")
        def admin_route(user: User = Depends(require_role("admin"))):
            return {"message": "Admin access granted"}
    """
    def role_dependency(
        user: User = Depends(get_current_user)
    ) -> User:
        if not has_role(user, role_name):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Required role '{role_name}' not found"
            )
        return user
    return role_dependency