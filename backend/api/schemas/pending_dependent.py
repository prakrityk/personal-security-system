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

# class GuardianDetailResponse(BaseModel):
#     """Response model for guardian details (dependent viewing their guardians)"""
#     id: int = Field(..., description="Relationship ID")
#     guardian_id: int = Field(..., description="Guardian user ID")
#     guardian_name: str = Field(..., description="Guardian full name")
#     guardian_email: str = Field(..., description="Guardian email")
#     relation: str = Field(..., description="Relation type (child/elderly)")
#     is_primary: bool = Field(..., description="Is this the primary guardian?")
#     guardian_type: str = Field(..., description="Guardian type (primary/collaborator)")  # ✅ ADDED
#     linked_at: datetime = Field(..., description="When the relationship was created")
    
#     class Config:
#         from_attributes = True
#         json_schema_extra = {
#             "example": {
#                 "id": 1,
#                 "guardian_id": 5,
#                 "guardian_name": "Jane Doe",
#                 "guardian_email": "jane@example.com",
#                 "relation": "child",
#                 "is_primary": True,
#                 "guardian_type": "primary",  # ✅ ADDED
#                 "linked_at": "2025-01-30T10:00:00Z"
#             }
#         }

# ================================================
# PENDING DEPENDENT SCHEMAS
# ================================================

class PendingDependentCreate(BaseModel):
    """Schema for creating a pending dependent"""
    dependent_name: str = Field(..., min_length=1, max_length=100)
    relation: str = Field(..., pattern="^(child|elderly)$")
    age: int = Field(..., ge=0, le=150, alias="age")
    
    class Config:
        populate_by_name = True


class PendingDependentResponse(BaseModel):
    """Schema for pending dependent response"""
    id: int
    guardian_id: int
    dependent_name: str
    relation: str
    age: int = Field(..., alias="Age")
    created_at: datetime
    
    class Config:
        populate_by_name = True
        from_attributes = True


class PendingDependentWithQR(BaseModel):
    """Schema for pending dependent with QR information"""
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
        populate_by_name = True
        from_attributes = True


# ================================================
# QR CODE SCHEMAS
# ================================================

class GenerateQRRequest(BaseModel):
    """Schema for QR generation request"""
    pending_dependent_id: int


class GenerateQRResponse(BaseModel):
    """
    ✅ FIXED: Schema for QR generation response
    Matches what guardian.py actually returns
    """
    success: bool
    message: str
    qr_token: str
    expires_at: datetime
    pending_dependent_id: int
    
    class Config:
        from_attributes = True


# ================================================
# SCAN & APPROVE SCHEMAS
# ================================================

class ScanQRRequest(BaseModel):
    """Schema for scanning QR code"""
    qr_token: str


class ScanQRResponse(BaseModel):
    """Schema for QR scan response"""
    success: bool
    message: str
    guardian_name: str
    dependent_name: str
    relation: str
    age: int
    qr_invitation_id: int


class ApproveQRRequest(BaseModel):
    """Schema for approving QR invitation"""
    qr_invitation_id: int


class ApproveQRResponse(BaseModel):
    """Schema for approval response"""
    success: bool
    message: str
    relationship_id: int
    guardian_id: int
    dependent_id: int
    relation: str


class RejectQRRequest(BaseModel):
    """Schema for rejecting QR invitation"""
    qr_invitation_id: int


# ================================================
# DEPENDENT & GUARDIAN DETAIL SCHEMAS
# ================================================

class DependentDetailResponse(BaseModel):
    """Schema for dependent details with relationship info"""
    id: int  # relationship_id
    dependent_id: int
    dependent_name: str
    dependent_email: str
    profile_picture: Optional[str] = None
    relation: str
    age: Optional[int] = Field(None, alias="Age")
    is_primary: bool
    guardian_type: Optional[str] = None  # "primary" or "collaborator"
    linked_at: datetime
    
    class Config:
        populate_by_name = True
        from_attributes = True


class GuardianDetailResponse(BaseModel):
    """Schema for guardian details with relationship info"""
    id: int  # relationship_id
    guardian_id: int
    guardian_name: str
    guardian_email: str
    phone_number: Optional[str] = None
    relation: str
    is_primary: bool
    guardian_type: Optional[str] = None  # "primary" or "collaborator"
    profile_picture: Optional[str] = None
    linked_at: datetime
    
    class Config:
        from_attributes = True


class PendingQRInvitationResponse(BaseModel):
    """Schema for pending QR invitation (scanned but not approved)"""
    qr_invitation_id: int
    pending_dependent_id: int
    dependent_name: str
    relation: str
    age: int = Field(..., alias="Age")
    status: str
    scanned_by_user_id: Optional[int] = None
    scanned_by_name: Optional[str] = None
    scanned_at: Optional[datetime] = None
    created_at: datetime
    expires_at: datetime
    
    class Config:
        populate_by_name = True
        from_attributes = True
