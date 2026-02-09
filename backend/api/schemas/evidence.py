from datetime import datetime
from typing import Optional
from pydantic import BaseModel


# ================================================
# BASE SCHEMA (shared fields)
# ================================================

class EvidenceBase(BaseModel):
    evidence_type: str                 # 'video' or 'audio'
    local_path: str
    file_size: Optional[int] = None    # bytes
    duration: Optional[int] = None     # seconds


# ================================================
# CREATE SCHEMA
# ================================================

class EvidenceCreate(EvidenceBase):
    """
    Used when creating evidence metadata
    upload_status is always 'pending' at creation
    """
    pass


# ================================================
# UPDATE SCHEMA (UPLOAD COMPLETE / FAILED)
# ================================================

class EvidenceUpdate(BaseModel):
    """
    Used when marking evidence as uploaded or failed
    """
    file_url: Optional[str] = None
    upload_status: str                 # 'uploaded' | 'failed'


# ================================================
# RESPONSE SCHEMA
# ================================================

class EvidenceResponse(EvidenceBase):
    id: int
    user_id: int

    file_url: Optional[str] = None
    upload_status: str

    created_at: datetime
    uploaded_at: Optional[datetime] = None

    class Config:
        form_attributes = True


# ================================================
# DELETE RESPONSE
# ================================================

class EvidenceDeleteResponse(BaseModel):
    success: bool
    message: str
