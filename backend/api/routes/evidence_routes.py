"""
Evidence Routes
Handles evidence collection operations: create, update, list, delete
Only available for dependent users (child/elderly roles)
"""

from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

# Schemas
from api.schemas.evidence import (
    EvidenceCreate,
    EvidenceUpdate,
    EvidenceResponse,
    EvidenceDeleteResponse
)

# Models
from models.user import User
from models.evidence import Evidence
from models.role import Role
from models.user_roles import UserRole

# Dependencies
from api.dependencies.auth import get_current_user
from database.connection import get_db

# Create router without prefix (will be added in main.py)
router = APIRouter(tags=["evidence"])


# ================================================
# HELPER FUNCTIONS
# ================================================

def verify_dependent_role(current_user: User, db: Session):
    """Verify that the current user has child or elderly role"""
    user_roles = db.query(Role).join(UserRole).filter(
        UserRole.user_id == current_user.id
    ).all()
    
    is_dependent = any(role.role_name in ["child", "elderly"] for role in user_roles)
    
    if not is_dependent:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Evidence collection only available for dependents (child/elderly roles)"
        )
    
    return True


# ================================================
# CREATE EVIDENCE RECORD
# ================================================

@router.post("/create", response_model=EvidenceResponse, status_code=status.HTTP_201_CREATED)
async def create_evidence(
    evidence: EvidenceCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create new evidence record after recording
    Stores metadata immediately, file upload happens later
    
    Requires: child or elderly role
    """
    try:
        print(f"📹 User {current_user.id} creating evidence: {evidence.evidence_type}")
        
        # Verify user has dependent role
        verify_dependent_role(current_user, db)
        
        # Create evidence record
        db_evidence = Evidence(
            user_id=current_user.id,
            evidence_type=evidence.evidence_type,
            local_path=evidence.local_path,
            file_size=evidence.file_size,
            duration=evidence.duration,
            upload_status="pending"
        )
        
        db.add(db_evidence)
        db.commit()
        db.refresh(db_evidence)
        
        print(f"✅ Evidence created: ID={db_evidence.id}")
        
        return db_evidence
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating evidence: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create evidence record: {str(e)}"
        )


# ================================================
# UPDATE EVIDENCE (MARK AS UPLOADED)
# ================================================

@router.patch("/{evidence_id}/uploaded", response_model=EvidenceResponse)
async def mark_evidence_uploaded(
    evidence_id: int,
    update: EvidenceUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Update evidence after successful upload to Google Drive
    Sets file_url, upload_status, and uploaded_at timestamp
    
    Requires: Must be the evidence owner
    """
    try:
        print(f"☁️ Updating evidence {evidence_id} upload status")
        
        # Find evidence owned by current user
        evidence = db.query(Evidence).filter(
            Evidence.id == evidence_id,
            Evidence.user_id == current_user.id
        ).first()
        
        if not evidence:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Evidence not found or you don't have permission to update it"
            )
        
        # Update evidence
        evidence.file_url = update.file_url
        evidence.upload_status = update.upload_status
        evidence.uploaded_at = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(evidence)
        
        print(f"✅ Evidence {evidence_id} marked as {update.upload_status}")
        
        return evidence
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error updating evidence: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update evidence: {str(e)}"
        )


# ================================================
# GET PENDING UPLOADS
# ================================================

@router.get("/pending", response_model=List[EvidenceResponse])
async def get_pending_uploads(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all evidence records with pending upload status
    Used by background worker to retry uploads
    
    Returns: List of evidence with upload_status='pending'
    """
    try:
        print(f"📋 Fetching pending uploads for user {current_user.id}")
        
        # Verify dependent role
        verify_dependent_role(current_user, db)
        
        # Get pending evidence
        pending = db.query(Evidence).filter(
            Evidence.user_id == current_user.id,
            Evidence.upload_status == "pending"
        ).order_by(Evidence.created_at.asc()).all()
        
        print(f"✅ Found {len(pending)} pending uploads")
        
        return pending
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching pending uploads: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch pending uploads: {str(e)}"
        )


# ================================================
# GET ALL MY EVIDENCE
# ================================================

@router.get("/my-evidence", response_model=List[EvidenceResponse])
async def get_my_evidence(
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all evidence records for current user
    
    Query params:
    - limit: Maximum number of records (default: 50)
    - offset: Number of records to skip (default: 0)
    
    Returns: List of evidence ordered by creation date (newest first)
    """
    try:
        print(f"📂 Fetching evidence for user {current_user.id}")
        
        # Verify dependent role
        verify_dependent_role(current_user, db)
        
        # Get evidence with pagination
        evidence = db.query(Evidence).filter(
            Evidence.user_id == current_user.id
        ).order_by(
            Evidence.created_at.desc()
        ).limit(limit).offset(offset).all()
        
        print(f"✅ Retrieved {len(evidence)} evidence records")
        
        return evidence
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching evidence: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch evidence: {str(e)}"
        )


# ================================================
# DELETE EVIDENCE
# ================================================

@router.delete("/{evidence_id}", response_model=EvidenceDeleteResponse)
async def delete_evidence(
    evidence_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete an evidence record
    Note: This only deletes the database record, not the actual file
    
    Requires: Must be the evidence owner
    """
    try:
        print(f"🗑️ Deleting evidence {evidence_id}")
        
        # Find evidence owned by current user
        evidence = db.query(Evidence).filter(
            Evidence.id == evidence_id,
            Evidence.user_id == current_user.id
        ).first()
        
        if not evidence:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Evidence not found or you don't have permission to delete it"
            )
        
        # Delete evidence
        db.delete(evidence)
        db.commit()
        
        print(f"✅ Evidence {evidence_id} deleted successfully")
        
        return EvidenceDeleteResponse(
            success=True,
            message="Evidence deleted successfully"
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting evidence: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete evidence: {str(e)}"
        )


# ================================================
# GET SINGLE EVIDENCE BY ID
# ================================================

@router.get("/{evidence_id}", response_model=EvidenceResponse)
async def get_evidence_by_id(
    evidence_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get specific evidence record by ID
    
    Requires: Must be the evidence owner
    """
    try:
        print(f"🔍 Fetching evidence {evidence_id}")
        
        # Find evidence owned by current user
        evidence = db.query(Evidence).filter(
            Evidence.id == evidence_id,
            Evidence.user_id == current_user.id
        ).first()
        
        if not evidence:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Evidence not found or you don't have permission to view it"
            )
        
        print(f"✅ Evidence {evidence_id} retrieved")
        
        return evidence
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching evidence: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch evidence: {str(e)}"
        )
