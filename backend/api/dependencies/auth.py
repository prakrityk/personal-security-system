"""
Authentication utilities and dependencies
Password hashing, JWT token generation, and user authentication
"""
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt as jose_jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session, joinedload
import os
import hashlib
from dotenv import load_dotenv
from database.connection import get_db
from models.user import User
from models.role import Role
from models.refresh_token import RefreshToken
import secrets
import random

load_dotenv()

# --------------------
# Password hashing
# --------------------
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

def hash_password(password: str) -> str:
    if not isinstance(password, str):
        raise TypeError("Password must be a string")
    sha256_password = hashlib.sha256(password.encode("utf-8")).hexdigest()
    return pwd_context.hash(sha256_password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    sha256_password = hashlib.sha256(plain_password.encode("utf-8")).hexdigest()
    return pwd_context.verify(sha256_password, hashed_password)

# --------------------
# JWT configuration
# --------------------
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-this-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

bearer_scheme = HTTPBearer()

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jose_jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> Optional[dict]:
    try:
        payload = jose_jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None

# --------------------
# Current user dependency
# --------------------
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db)
):
    token = credentials.credentials
    try:
        payload = jose_jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = int(payload.get("sub"))

        # Load user with roles using joinedload
        user = db.query(User).options(joinedload(User.roles)).filter(User.id == user_id).first()
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )

        # Convert roles to simple list
        user.role_names = [role.role_name for role in user.roles] if hasattr(user, "roles") else []

        return user

    except jose_jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired"
        )
    except jose_jwt.JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

# --------------------
# Verification code generation
# --------------------
def generate_verification_code() -> str:
    return str(random.randint(100000, 999999))

# --------------------
# Refresh token management
# --------------------
def create_refresh_token(user_id: int, db: Session, device_info: str = None, ip_address: str = None):
    token_string = RefreshToken.generate_token()
    expires_at = RefreshToken.calculate_expiry(days=30)
    
    refresh_token = RefreshToken(
        token=token_string,
        user_id=user_id,
        expires_at=expires_at,
        device_info=device_info,
        #ip_address=ip_address
    )
    db.add(refresh_token)
    db.commit()
    db.refresh(refresh_token)
    return refresh_token

def verify_refresh_token(token: str, db: Session):
    refresh_token = db.query(RefreshToken).filter(
        RefreshToken.token == token
    ).first()
    
    if not refresh_token or not refresh_token.is_valid():
        return None

    refresh_token.last_used_at = datetime.utcnow()
    db.commit()
    return refresh_token

def revoke_refresh_token(token: str, db: Session):
    refresh_token = db.query(RefreshToken).filter(
        RefreshToken.token == token
    ).first()
    if refresh_token:
        refresh_token.is_revoked = True
        db.commit()
        return True
    return False

def revoke_all_user_tokens(user_id: int, db: Session):
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user_id,
        RefreshToken.is_revoked == False
    ).update({"is_revoked": True})
    db.commit()
