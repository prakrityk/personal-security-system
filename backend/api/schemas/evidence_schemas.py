"""
Pydantic schemas for Evidence endpoints
Validation for evidence collection feature
"""

from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional


# =====================================================
# REQUEST SCHEMAS
# =====================================================

class EvidenceCreate(BaseModel):
    """Schema for creating new evidence record"""
    evidence_type: str = Field(..., description="Type of evidence: video or audio")
    local_path: str = Field(..., description="Local device file path")
    file_size: Optional[int] = Field(None, description="File size in bytes")
    duration: Optional[int] = Field(None, description="Duration in seconds")
    
    @field_validator('evidence_type')
    @classmethod
    def validate_evidence_type(cls, v):
        if v not in ['video', 'audio']:
            raise ValueError('evidence_type must be either "video" or "audio"')
        return v
    
    @field_validator('file_size')
    @classmethod
    def validate_file_size(cls, v):
        if v is not None and v < 0:
            raise ValueError('file_size cannot be negative')
        return v
    
    @field_validator('duration')
    @classmethod
    def validate_duration(cls, v):
        if v is not None and v < 0:
            raise ValueError('duration cannot be negative')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "evidence_type": "video",
                "local_path": "/storage/emulated/0/SecurityApp/evidence/video_20260203_124530.mp4",
                "file_size": 5242880,
                "duration": 30
            }
        }


class EvidenceUpdate(BaseModel):
    """Schema for updating evidence after upload"""
    file_url: str = Field(..., description="Google Drive file ID or URL")
    upload_status: str = Field(..., description="Upload status: uploaded or failed")
    
    @field_validator('upload_status')
    @classmethod
    def validate_upload_status(cls, v):
        if v not in ['uploaded', 'failed']:
            raise ValueError('upload_status must be either "uploaded" or "failed"')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "file_url": "1a2b3c4d5e6f7g8h9i0j",
                "upload_status": "uploaded"
            }
        }


# =====================================================
# RESPONSE SCHEMAS
# =====================================================

class EvidenceResponse(BaseModel):
    """Response schema for evidence data"""
    id: int
    user_id: int
    evidence_type: str
    local_path: str
    file_url: Optional[str] = None
    upload_status: str
    file_size: Optional[int] = None
    duration: Optional[int] = None
    created_at: datetime
    uploaded_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": 1,
                "user_id": 42,
                "evidence_type": "video",
                "local_path": "/storage/emulated/0/SecurityApp/evidence/video_20260203_124530.mp4",
                "file_url": "1a2b3c4d5e6f7g8h9i0j",
                "upload_status": "uploaded",
                "file_size": 5242880,
                "duration": 30,
                "created_at": "2026-02-03T12:45:30Z",
                "uploaded_at": "2026-02-03T12:46:15Z"
            }
        }


class EvidenceListResponse(BaseModel):
    """Response schema for list of evidence"""
    total: int
    evidence: list[EvidenceResponse]
    
    class Config:
        json_schema_extra = {
            "example": {
                "total": 2,
                "evidence": [
                    {
                        "id": 1,
                        "user_id": 42,
                        "evidence_type": "video",
                        "upload_status": "uploaded"
                    }
                ]
            }
        }


class EvidenceDeleteResponse(BaseModel):
    """Response for evidence deletion"""
    success: bool
    message: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Evidence deleted successfully"
            }
        }