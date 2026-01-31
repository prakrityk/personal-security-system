"""
Pydantic schemas for emergency contact endpoints
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime


# ================================================
# EMERGENCY CONTACT SCHEMAS
# ================================================

class EmergencyContactCreate(BaseModel):
    """Schema for creating an emergency contact"""
    contact_name: str = Field(..., min_length=1, max_length=100, description="Name of emergency contact")
    contact_phone: str = Field(..., min_length=10, max_length=20, description="Phone number")
    contact_email: Optional[str] = Field(None, max_length=255, description="Email address (optional)")
    relationship: Optional[str] = Field(None, max_length=50, description="Relationship to user")
    priority: int = Field(default=999, ge=1, le=999, description="Priority (1=highest)")
    
    @field_validator('contact_name')
    @classmethod
    def name_must_not_be_empty(cls, v):
        if not v or v.strip() == "":
            raise ValueError('Contact name cannot be empty')
        return v.strip()
    
    @field_validator('contact_phone')
    @classmethod
    def validate_phone(cls, v):
        # Remove spaces and special characters
        phone = v.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        if not phone.startswith('+'):
            raise ValueError('Phone number must start with + and country code')
        if not phone[1:].isdigit():
            raise ValueError('Phone number must contain only digits after +')
        if len(phone) < 11 or len(phone) > 16:
            raise ValueError('Phone number must be between 10-15 digits (excluding +)')
        return phone
    
    class Config:
        json_schema_extra = {
            "example": {
                "contact_name": "Jane Doe",
                "contact_phone": "+9779812345678",
                "contact_email": "jane@example.com",
                "relationship": "Mother",
                "priority": 1
            }
        }


class EmergencyContactUpdate(BaseModel):
    """Schema for updating an emergency contact"""
    contact_name: Optional[str] = Field(None, min_length=1, max_length=100)
    contact_phone: Optional[str] = Field(None, min_length=10, max_length=20)
    contact_email: Optional[str] = Field(None, max_length=255)
    relationship: Optional[str] = Field(None, max_length=50)
    priority: Optional[int] = Field(None, ge=1, le=999)
    is_active: Optional[bool] = None
    
    @field_validator('contact_name')
    @classmethod
    def name_must_not_be_empty(cls, v):
        if v is not None and (not v or v.strip() == ""):
            raise ValueError('Contact name cannot be empty')
        return v.strip() if v else v
    
    @field_validator('contact_phone')
    @classmethod
    def validate_phone(cls, v):
        if v is None:
            return v
        phone = v.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        if not phone.startswith('+'):
            raise ValueError('Phone number must start with + and country code')
        if not phone[1:].isdigit():
            raise ValueError('Phone number must contain only digits after +')
        if len(phone) < 11 or len(phone) > 16:
            raise ValueError('Phone number must be between 10-15 digits (excluding +)')
        return phone


class EmergencyContactResponse(BaseModel):
    """Schema for emergency contact response"""
    id: int
    user_id: int
    contact_name: str
    contact_phone: str
    contact_email: Optional[str] = None
    relationship: Optional[str] = None
    priority: int
    is_active: bool
    source: str  # manual, phone_contacts, auto_guardian
    guardian_relationship_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "user_id": 5,
                "contact_name": "Jane Doe",
                "contact_phone": "+9779812345678",
                "contact_email": "jane@example.com",
                "relationship": "Mother",
                "priority": 1,
                "is_active": True,
                "source": "manual",
                "guardian_relationship_id": None,
                "created_at": "2025-01-30T10:00:00Z",
                "updated_at": "2025-01-30T10:00:00Z"
            }
        }


class EmergencyContactBulkCreate(BaseModel):
    """Schema for creating multiple emergency contacts at once (from phone)"""
    contacts: List[EmergencyContactCreate] = Field(..., min_items=1, max_items=50)
    
    class Config:
        json_schema_extra = {
            "example": {
                "contacts": [
                    {
                        "contact_name": "Jane Doe",
                        "contact_phone": "+9779812345678",
                        "relationship": "Mother",
                        "priority": 1
                    },
                    {
                        "contact_name": "John Smith",
                        "contact_phone": "+9779887654321",
                        "relationship": "Father",
                        "priority": 2
                    }
                ]
            }
        }


class EmergencyContactBulkResponse(BaseModel):
    """Response after bulk create"""
    success: bool
    message: str
    created_count: int
    failed_count: int
    contacts: List[EmergencyContactResponse]
    errors: Optional[List[str]] = None


class DependentEmergencyContactCreate(BaseModel):
    """Schema for primary guardian to add emergency contact for dependent"""
    dependent_id: int = Field(..., description="ID of the dependent")
    contact_name: str = Field(..., min_length=1, max_length=100)
    contact_phone: str = Field(..., min_length=10, max_length=20)
    contact_email: Optional[str] = Field(None, max_length=255)
    relationship: Optional[str] = Field(None, max_length=50)
    priority: int = Field(default=999, ge=1, le=999)
    
    @field_validator('contact_name')
    @classmethod
    def name_must_not_be_empty(cls, v):
        if not v or v.strip() == "":
            raise ValueError('Contact name cannot be empty')
        return v.strip()
    
    @field_validator('contact_phone')
    @classmethod
    def validate_phone(cls, v):
        phone = v.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        if not phone.startswith('+'):
            raise ValueError('Phone number must start with + and country code')
        if not phone[1:].isdigit():
            raise ValueError('Phone number must contain only digits after +')
        if len(phone) < 11 or len(phone) > 16:
            raise ValueError('Phone number must be between 10-15 digits (excluding +)')
        return phone


class DependentEmergencyContactUpdate(BaseModel):
    """Schema for primary guardian to update dependent's emergency contact"""
    contact_name: Optional[str] = Field(None, min_length=1, max_length=100)
    contact_phone: Optional[str] = Field(None, min_length=10, max_length=20)
    contact_email: Optional[str] = Field(None, max_length=255)
    relationship: Optional[str] = Field(None, max_length=50)
    priority: Optional[int] = Field(None, ge=1, le=999)
    is_active: Optional[bool] = None