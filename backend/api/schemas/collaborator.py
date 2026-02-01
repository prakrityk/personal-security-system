"""
Pydantic schemas for collaborator guardian endpoints
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ================================================
# COLLABORATOR INVITATION SCHEMAS
# ================================================

class CreateCollaboratorInvitationRequest(BaseModel):
    """Request to create a collaborator invitation"""
    dependent_id: int = Field(..., description="ID of the dependent to share")
    
    class Config:
        json_schema_extra = {
            "example": {
                "dependent_id": 5
            }
        }


class CollaboratorInvitationResponse(BaseModel):
    """Response after creating invitation"""
    id: int
    invitation_code: str
    dependent_id: int
    dependent_name: str
    expires_at: datetime
    status: str
    qr_data: str  # The invitation code formatted for QR
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "invitation_code": "abc123xyz789",
                "dependent_id": 5,
                "dependent_name": "John Doe",
                "expires_at": "2025-02-04T10:30:00Z",
                "status": "pending",
                "qr_data": "COLLAB:abc123xyz789"
            }
        }


class ValidateInvitationRequest(BaseModel):
    """Request to validate an invitation code"""
    invitation_code: str = Field(..., min_length=10, description="Invitation code to validate")
    
    class Config:
        json_schema_extra = {
            "example": {
                "invitation_code": "abc123xyz789"
            }
        }


class ValidateInvitationResponse(BaseModel):
    """Response with dependent preview info"""
    valid: bool
    message: str
    dependent_id: Optional[int] = None
    dependent_name: Optional[str] = None
    dependent_age: Optional[int] = None
    relation: Optional[str] = None
    primary_guardian_name: Optional[str] = None
    expires_at: Optional[datetime] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "valid": True,
                "message": "Invitation is valid",
                "dependent_id": 5,
                "dependent_name": "John Doe",
                "dependent_age": 10,
                "relation": "child",
                "primary_guardian_name": "Jane Doe",
                "expires_at": "2025-02-04T10:30:00Z"
            }
        }


class AcceptInvitationRequest(BaseModel):
    """Request to accept an invitation"""
    invitation_code: str = Field(..., min_length=10, description="Invitation code to accept")
    
    class Config:
        json_schema_extra = {
            "example": {
                "invitation_code": "abc123xyz789"
            }
        }


class AcceptInvitationResponse(BaseModel):
    """Response after accepting invitation"""
    success: bool
    message: str
    relationship_id: int
    guardian_id: int
    dependent_id: int
    dependent_name: str
    relation: str
    guardian_type: str  # "collaborator"
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Successfully joined as collaborator guardian",
                "relationship_id": 10,
                "guardian_id": 3,
                "dependent_id": 5,
                "dependent_name": "John Doe",
                "relation": "child",
                "guardian_type": "collaborator"
            }
        }


class CollaboratorInfo(BaseModel):
    """Info about a collaborator guardian"""
    relationship_id: int
    guardian_id: int
    guardian_name: str
    guardian_email: str
    joined_at: datetime
    guardian_type: str = "collaborator"
    
    class Config:
        from_attributes = True


class PendingInvitationInfo(BaseModel):
    """Info about a pending invitation"""
    id: int
    invitation_code: str
    created_at: datetime
    expires_at: datetime
    status: str
    
    class Config:
        from_attributes = True


class RevokeCollaboratorRequest(BaseModel):
    """Request to revoke collaborator access"""
    relationship_id: int = Field(..., description="ID of the guardian-dependent relationship to revoke")
    
    class Config:
        json_schema_extra = {
            "example": {
                "relationship_id": 10
            }
        }


# ================================================
# DEPENDENT DETAIL WITH GUARDIAN TYPE
# ================================================

class DependentDetailWithGuardianType(BaseModel):
    """Extended dependent detail including guardian type"""
    id: int
    dependent_id: int
    dependent_name: str
    dependent_email: str
    relation: str
    Age: Optional[int] = None
    is_primary: bool
    guardian_type: str  # "primary" or "collaborator"
    linked_at: datetime
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 10,
                "dependent_id": 5,
                "dependent_name": "John Doe",
                "dependent_email": "john@example.com",
                "relation": "child",
                "Age": 10,
                "is_primary": False,
                "guardian_type": "collaborator",
                "linked_at": "2025-01-28T10:30:00Z"
            }
        }