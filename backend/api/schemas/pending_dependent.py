"""
Pending Dependent Schemas
Pydantic models for API request/response validation
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import datetime


# ----------------------
# Pending Dependent Schemas
# ----------------------
class PendingDependentCreate(BaseModel):

    """Schema for creating a pending dependent"""
    dependent_name: str = Field(..., min_length=1, max_length=250, description="Name of the dependent")
    relation: str = Field(..., min_length=1, max_length=50, description="Relationship (e.g., 'son', 'daughter', 'parent')")
    age: int = Field(..., ge=0, le=150, alias="Age")  # ✅ Correct
    
    @field_validator('dependent_name')
    @classmethod
    def name_must_not_be_empty(cls, v):
        if not v or v.strip() == "":
            raise ValueError('Dependent name cannot be empty')
        return v.strip()

    @field_validator('relation')
    @classmethod
    def relation_must_not_be_empty(cls, v):
        if not v or v.strip() == "":
            raise ValueError('Relation cannot be empty')
        return v.strip()


class PendingDependentResponse(BaseModel):
    """Schema for pending dependent response"""
    id: int
    guardian_id: int
    dependent_name: str
    relation: str
    age: int = Field(..., alias="Age")
    created_at: datetime

    class Config:
        from_attributes = True
        populate_by_name = True


class PendingDependentWithQR(BaseModel):
    """Schema for pending dependent with QR info"""
    id: int
    guardian_id: int
    dependent_name: str
    relation: str
    age: int = Field(..., alias="Age")
    created_at: datetime
    has_qr: bool = False
    qr_status: Optional[str] = None
    qr_token: Optional[str] = None

    class Config:
        from_attributes = True
        populate_by_name = True


# ----------------------
# QR Invitation Schemas
# ----------------------
class GenerateQRRequest(BaseModel):
    """Schema for generating QR code"""
    pending_dependent_id: int = Field(..., description="ID of the pending dependent")


class GenerateQRResponse(BaseModel):
    """Schema for QR generation response"""
    success: bool
    message: str
    qr_token: str
    expires_at: datetime
    pending_dependent_id: int


class ScanQRRequest(BaseModel):
    """Schema for scanning QR code"""
    qr_token: str = Field(..., min_length=1, description="QR token to scan")


class ScanQRResponse(BaseModel):
    """Schema for QR scan response"""
    success: bool
    message: str
    guardian_name: str
    dependent_name: str
    relation: str
    age: int = Field(..., alias="Age")  
    qr_invitation_id: int
    class Config:
        populate_by_name = True  # ✅ Added

class ApproveQRRequest(BaseModel):
    """Schema for approving scanned QR"""
    qr_invitation_id: int = Field(..., description="ID of the QR invitation to approve")


class ApproveQRResponse(BaseModel):
    """Schema for approval response"""
    success: bool
    message: str
    relationship_id: int
    guardian_id: int
    dependent_id: int
    relation: str


class RejectQRRequest(BaseModel):
    """Schema for rejecting scanned QR"""
    qr_invitation_id: int = Field(..., description="ID of the QR invitation to reject")


# ----------------------
# Guardian-Dependent Relationship Schemas
# ----------------------
class GuardianDependentResponse(BaseModel):
    """Schema for guardian-dependent relationship"""
    id: int
    guardian_id: int
    dependent_id: int
    relation: str
    is_primary: bool
    created_at: datetime

    class Config:
        from_attributes = True


class DependentDetailResponse(BaseModel):
    """Schema for detailed dependent information"""
    id: int
    dependent_id: int
    dependent_name: str
    dependent_email: str
    relation: str
    age: Optional[int] = Field(None, alias="Age")
    is_primary: bool
    linked_at: datetime

    class Config:
        from_attributes = True
        populate_by_name = True


class GuardianDetailResponse(BaseModel):
    """Schema for detailed guardian information"""
    id: int
    guardian_id: int
    guardian_name: str
    guardian_email: str
    relation: str
    is_primary: bool
    linked_at: datetime

    class Config:
        from_attributes = True


# ----------------------
# Pending QR Invitations for Guardian
# ----------------------
class PendingQRInvitationResponse(BaseModel):
    """Schema for pending QR invitations (for guardian to see)"""
    qr_invitation_id: int
    pending_dependent_id: int
    dependent_name: str
    relation: str
    age: Optional[int] = Field(None, alias="Age")
    status: str
    scanned_by_user_id: Optional[int] = None
    scanned_by_name: Optional[str] = None
    scanned_at: Optional[datetime] = None
    created_at: datetime
    expires_at: datetime

    class Config:
        from_attributes = True
        populate_by_name = True