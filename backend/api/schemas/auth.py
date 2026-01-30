"""
Pydantic schemas for authentication endpoints
Updated for Firebase Authentication Integration
"""

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List
from datetime import datetime


# =====================================================
# FIREBASE AUTHENTICATION SCHEMAS
# =====================================================

class FirebaseTokenVerification(BaseModel):
    """Schema for verifying Firebase ID token"""
    firebase_token: str = Field(..., description="Firebase ID token from Flutter client")
    
    class Config:
        json_schema_extra = {
            "example": {
                "firebase_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjFmOD..."
            }
        }


class FirebaseRegistrationComplete(BaseModel):
    """Schema for completing registration with Firebase token"""
    firebase_token: str = Field(..., description="Firebase ID token (proof of verification)")
    full_name: str = Field(..., min_length=2, max_length=100, description="User's full name")
    password: str = Field(..., min_length=8, description="Password for daily login")
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(char.islower() for char in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one number')
        if not any(char in '@$!%*?&#' for char in v):
            raise ValueError('Password must contain at least one special character (@$!%*?&#)')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "firebase_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjFmOD...",
                "full_name": "John Doe",
                "password": "SecurePass123!"
            }
        }


# =====================================================
# TRADITIONAL LOGIN (Email/Password)
# =====================================================

class UserLogin(BaseModel):
    """Schema for user login with email/password"""
    email: str = Field(..., description="Email or phone number")
    password: str = Field(..., description="Password")
    
    class Config:
        json_schema_extra = {
            "example": {
                "email": "john.doe@example.com",
                "password": "SecurePass123!"
            }
        }


# =====================================================
# TOKEN SCHEMAS
# =====================================================

class Token(BaseModel):
    """Response schema for JWT token"""
    access_token: str
    token_type: str = "bearer"


class TokenResponse(BaseModel):
    """Response with both access and refresh tokens"""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int  # seconds until access token expires


class RefreshTokenRequest(BaseModel):
    """Request to refresh access token"""
    refresh_token: str


# =====================================================
# ROLE SCHEMAS
# =====================================================

class RoleInfo(BaseModel):
    """Schema for role information"""
    id: int
    role_name: str
    role_description: Optional[str] = None
    
    class Config:
        from_attributes = True


class RoleSelectRequest(BaseModel):
    """Request to select a role"""
    role_id: int = Field(..., description="ID of the role to assign")


# =====================================================
# USER SCHEMAS
# =====================================================

class UserResponse(BaseModel):
    """Response schema for user data"""
    id: int
    email: str
    full_name: str
    phone_number: str
    roles: List[RoleInfo] = []
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "email": "john.doe@example.com",
                "full_name": "John Doe",
                "phone_number": "+9779812345678",
                "roles": []
            }
        }


class UserWithToken(BaseModel):
    """Response schema for registration/login - returns user + single token"""
    user: UserResponse
    token: Token


class UserWithTokens(BaseModel):
    """User response with both access and refresh tokens"""
    user: UserResponse
    tokens: TokenResponse


# =====================================================
# AVAILABILITY CHECK SCHEMAS
# =====================================================

class EmailCheckResponse(BaseModel):
    """Response for email availability check"""
    available: bool
    message: str


class PhoneCheckResponse(BaseModel):
    """Response for phone number availability check"""
    available: bool
    message: str


# =====================================================
# LEGACY SCHEMAS (Keep for backward compatibility if needed)
# =====================================================

class UserRegister(BaseModel):
    """
    Legacy registration schema (not used with Firebase)
    Kept for backward compatibility
    """
    email: EmailStr
    password: str = Field(..., min_length=8)
    full_name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., description="Phone number with country code")
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not any(char.islower() for char in v):
            raise ValueError('Password must contain at least one lowercase letter')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one number')
        if not any(char in '@$!%*?&#' for char in v):
            raise ValueError('Password must contain at least one special character (@$!%*?&#)')
        return v
    
    @field_validator('phone_number')
    @classmethod
    def validate_phone_number(cls, v):
        # Remove spaces and dashes
        phone_number = v.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        # Check if it's a valid phone number format (starts with + and has 10-15 digits)
        if not phone_number.startswith('+'):
            raise ValueError('Phone number must start with + and country code')
        if not phone_number[1:].isdigit():
            raise ValueError('Phone number must contain only digits after +')
        if len(phone_number) < 11 or len(phone_number) > 16:
            raise ValueError('Phone number must be between 10-15 digits (excluding +)')
        return phone_number


class PhoneVerificationRequest(BaseModel):
    """Legacy - Request schema for sending phone verification code"""
    phone_number: str


class PhoneVerificationConfirm(BaseModel):
    """Legacy - Request schema for confirming phone verification"""
    phone_number: str
    verification_code: str = Field(..., min_length=6, max_length=6)