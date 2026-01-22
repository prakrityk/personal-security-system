"""
Pydantic schemas for authentication endpoints
"""

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List
import re


class UserRegister(BaseModel):
    """Request schema for user registration"""
    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters with uppercase, lowercase, number, and special character")
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
        # Check if it's a valid phone_number format (starts with + and has 10-15 digits)
        if not phone_number.startswith('+'):
            raise ValueError('phone_number number must start with + and country code')
        if not phone_number[1:].isdigit():
            raise ValueError('phone_number number must contain only digits after +')
        if len(phone_number) < 11 or len(phone_number) > 16:
            raise ValueError('phone_number number must be between 10-15 digits (excluding +)')
        return phone_number
    
    class Config:
        json_schema_extra = {
            "example": {
                "email": "john.doe@example.com",
                "password": "SecurePass123!",
                "full_name": "John Doe",
                "phone_number": "+9779812345678"
            }
        }


class PhoneVerificationRequest(BaseModel):
    """Request schema for sending phone_number verification code"""
    phone_number: str


class PhoneVerificationConfirm(BaseModel):
    """Request schema for confirming phone_number verification"""
    phone_number: str
    verification_code: str = Field(..., min_length=6, max_length=6)


class UserLogin(BaseModel):
    """Request schema for user login"""
    email: str  # Can be email or phone_number
    password: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "email": "john.doe@example.com",
                "password": "securepass123"
            }
        }


class Token(BaseModel):
    """Response schema for JWT token"""
    access_token: str
    token_type: str = "bearer"


class RoleInfo(BaseModel):
    """Schema for role information"""
    id: int
    role_name: str
    role_description: Optional[str] = None
    
    class Config:
        from_attributes = True


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
                "roles": []  # Empty until user selects path after login
            }
        }


class UserWithToken(BaseModel):
    """Response schema for registration/login - returns user + token"""
    user: UserResponse
    token: Token


class EmailCheckResponse(BaseModel):
    """Response for email availability check"""
    available: bool
    message: str


class PhoneCheckResponse(BaseModel):
    """Response for phone_number availability check"""
    available: bool
    message: str


class RoleSelectRequest(BaseModel):
    role_id: int