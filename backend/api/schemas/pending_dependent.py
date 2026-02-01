"""
Pydantic Schemas for Pending Dependent Endpoints
UPDATED: Added guardian_type to GuardianDetailResponse
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ================================================================
# GUARDIAN DETAIL RESPONSE - UPDATED WITH guardian_type
# ================================================================

class GuardianDetailResponse(BaseModel):
    """Response model for guardian details (dependent viewing their guardians)"""
    id: int = Field(..., description="Relationship ID")
    guardian_id: int = Field(..., description="Guardian user ID")
    guardian_name: str = Field(..., description="Guardian full name")
    guardian_email: str = Field(..., description="Guardian email")
    relation: str = Field(..., description="Relation type (child/elderly)")
    is_primary: bool = Field(..., description="Is this the primary guardian?")
    guardian_type: str = Field(..., description="Guardian type (primary/collaborator)")  # ✅ ADDED
    linked_at: datetime = Field(..., description="When the relationship was created")
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "guardian_id": 5,
                "guardian_name": "Jane Doe",
                "guardian_email": "jane@example.com",
                "relation": "child",
                "is_primary": True,
                "guardian_type": "primary",  # ✅ ADDED
                "linked_at": "2025-01-30T10:00:00Z"
            }
        }


# ================================================================
# OTHER SCHEMAS (keep your existing ones)
# ================================================================

class PendingDependentCreate(BaseModel):
    """Schema for creating a pending dependent"""
    dependent_name: str = Field(..., min_length=1, max_length=250)
    relation: str = Field(..., description="Relation type: 'child' or 'elderly'")
    age: int = Field(..., ge=1, le=150, description="Age of the dependent")  # Note: lowercase 'age'
    
    class Config:
        json_schema_extra = {
            "example": {
                "dependent_name": "John Doe",
                "relation": "child",
                "age": 10
            }
        }


class PendingDependentResponse(BaseModel):
    """Response after creating a pending dependent"""
    id: int
    guardian_id: int
    dependent_name: str
    relation: str
    age: int  # ✅ Using lowercase 'age' (SQLAlchemy maps to 'Age' in DB)
    created_at: datetime
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "guardian_id": 5,
                "dependent_name": "John Doe",
                "relation": "child",
                "age": 10,
                "created_at": "2025-01-30T10:00:00Z"
            }
        }


class PendingDependentWithQR(BaseModel):
    """Pending dependent with QR status information"""
    id: int
    guardian_id: int
    dependent_name: str
    relation: str
    age: int
    created_at: datetime
    has_qr: bool = Field(..., description="Whether QR code has been generated")
    qr_status: Optional[str] = Field(None, description="QR status if exists")
    qr_token: Optional[str] = Field(None, description="QR token if exists")
    
    class Config:
        from_attributes = True


class GenerateQRRequest(BaseModel):
    """Request to generate QR code"""
    pending_dependent_id: int = Field(..., description="ID of pending dependent")
    
    class Config:
        json_schema_extra = {
            "example": {
                "pending_dependent_id": 1
            }
        }


class GenerateQRResponse(BaseModel):
    """Response after generating QR code"""
    qr_invitation_id: int
    qr_token: str
    qr_url: str
    expires_at: datetime
    status: str
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "qr_invitation_id": 1,
                "qr_token": "abc123-def456-ghi789",
                "qr_url": "https://app.example.com/scan?token=abc123-def456-ghi789",
                "expires_at": "2025-02-03T10:00:00Z",
                "status": "pending"
            }
        }


class ScanQRRequest(BaseModel):
    """Request to scan QR code (dependent side)"""
    qr_token: str = Field(..., min_length=10, description="QR token to scan")
    
    class Config:
        json_schema_extra = {
            "example": {
                "qr_token": "abc123-def456-ghi789"
            }
        }


class ScanQRResponse(BaseModel):
    """Response after scanning QR code"""
    success: bool
    message: str
    guardian_name: str
    dependent_name: str
    relation: str
    age: int
    qr_invitation_id: int
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Successfully linked with Jane Doe!",
                "guardian_name": "Jane Doe",
                "dependent_name": "John Doe",
                "relation": "child",
                "age": 10,
                "qr_invitation_id": 1
            }
        }


class ApproveQRRequest(BaseModel):
    """Request to approve QR scan"""
    qr_invitation_id: int = Field(..., description="QR invitation ID to approve")
    
    class Config:
        json_schema_extra = {
            "example": {
                "qr_invitation_id": 1
            }
        }


class ApproveQRResponse(BaseModel):
    """Response after approving QR"""
    success: bool
    message: str
    relationship_id: int
    dependent_id: int
    dependent_name: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Relationship approved successfully",
                "relationship_id": 10,
                "dependent_id": 15,
                "dependent_name": "John Doe"
            }
        }


class RejectQRRequest(BaseModel):
    """Request to reject QR scan"""
    qr_invitation_id: int = Field(..., description="QR invitation ID to reject")
    
    class Config:
        json_schema_extra = {
            "example": {
                "qr_invitation_id": 1
            }
        }


class DependentDetailResponse(BaseModel):
    """Response for dependent details"""
    id: int  # Relationship ID
    dependent_id: int
    dependent_name: str
    dependent_email: str
    relation: str
    Age: Optional[int] = None  # Note: Capital 'A' to match DB column
    is_primary: bool
    linked_at: datetime
    
    class Config:
        from_attributes = True


class PendingQRInvitationResponse(BaseModel):
    """Response for pending QR invitations"""
    id: int
    qr_token: str
    dependent_name: str
    scanned_by_user_id: Optional[int] = None
    scanned_at: Optional[datetime] = None
    status: str
    created_at: datetime
    expires_at: datetime
    
    class Config:
        from_attributes = True