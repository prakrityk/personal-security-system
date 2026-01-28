"""
Dependent Routes
Handles dependent-related operations: QR scanning, viewing guardians
"""

from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

# Schemas
from api.schemas.pending_dependent import (
    ScanQRRequest,
    ScanQRResponse,
    GuardianDetailResponse,
)

# Models
from models.user import User
from models.pending_dependent import PendingDependent
from models.qr_invitation import QRInvitation
from models.guardian_dependent import GuardianDependent
from models.role import Role
from models.user_roles import UserRole

# Dependencies
from api.dependencies.auth import get_current_user
from database.connection import get_db

# ✅ FIX: Remove prefix here since it's added in main.py
router = APIRouter(tags=["dependent"])


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
            status_code=403,
            detail="User must have child or elderly role to perform this action"
        )
    
    return True


def assign_role_to_user(user_id: int, role_name: str, db: Session):
    """Assign a role to a user if they don't have it"""
    # Get the role
    role = db.query(Role).filter(Role.role_name == role_name).first()
    
    if not role:
        raise HTTPException(
            status_code=500,
            detail=f"Role '{role_name}' not found in system"
        )
    
    # Check if user already has this role
    existing = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role.id
    ).first()
    
    if not existing:
        # Assign the role
        user_role = UserRole(user_id=user_id, role_id=role.id)
        db.add(user_role)
        db.commit()
        print(f"✅ Assigned role '{role_name}' to user {user_id}")
    else:
        print(f"ℹ️  User {user_id} already has role '{role_name}'")


# ================================================
# SCAN QR CODE
# ================================================

@router.post("/scan-qr", response_model=ScanQRResponse)
async def scan_qr_code(
    request: ScanQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Dependent scans QR code to link with guardian
    This automatically creates the guardian-dependent relationship
    """
    try:
        print(f"📱 User {current_user.id} scanning QR: {request.qr_token}")
        
        # Verify user has child or elderly role
        verify_dependent_role(current_user, db)
        
        # Find QR invitation
        qr_invitation = db.query(QRInvitation).filter(
            QRInvitation.qr_token == request.qr_token
        ).first()
        
        if not qr_invitation:
            raise HTTPException(
                status_code=404,
                detail="Invalid QR code"
            )
        
        # Check if expired
        if qr_invitation.is_expired():
            qr_invitation.status = "expired"
            db.commit()
            raise HTTPException(
                status_code=400,
                detail="QR code has expired. Please ask your guardian for a new one."
            )
        
        # Check if already used
        if qr_invitation.status not in ["pending", "scanned"]:
            raise HTTPException(
                status_code=400,
                detail=f"QR code has already been {qr_invitation.status}"
            )
        
        # Check if user is trying to scan their own QR
        if qr_invitation.guardian_id == current_user.id:
            raise HTTPException(
                status_code=400,
                detail="You cannot scan your own QR code"
            )
        
        # Get pending dependent info
        pending_dependent = db.query(PendingDependent).filter(
            PendingDependent.id == qr_invitation.pending_dependent_id
        ).first()
        
        if not pending_dependent:
            raise HTTPException(
                status_code=404,
                detail="Pending dependent information not found"
            )
        
        # Get guardian info
        guardian = db.query(User).filter(
            User.id == qr_invitation.guardian_id
        ).first()
        
        if not guardian:
            raise HTTPException(
                status_code=404,
                detail="Guardian not found"
            )
        
        # ✅ Update QR invitation status
        qr_invitation.scanned_by_user_id = current_user.id
        qr_invitation.status = "approved"  # Auto-approve
        qr_invitation.is_approved = True
        qr_invitation.scanned_at = datetime.now(timezone.utc)
        qr_invitation.approved_at = datetime.now(timezone.utc)
        
        # ✅ Check if relationship already exists
        existing_relationship = db.query(GuardianDependent).filter(
            GuardianDependent.guardian_id == guardian.id,
            GuardianDependent.dependent_id == current_user.id
        ).first()
        
        if not existing_relationship:
            # ✅ Create guardian-dependent relationship
            new_relationship = GuardianDependent(
                guardian_id=guardian.id,
                dependent_id=current_user.id,
                relation=pending_dependent.relation,
                is_primary=True,  # First guardian is primary
                pending_dependent_id=pending_dependent.id
            )
            db.add(new_relationship)
            print(f"✅ Created guardian-dependent relationship: {guardian.id} → {current_user.id}")
        else:
            print(f"ℹ️  Guardian-dependent relationship already exists")
        
        # ✅ Ensure user has the correct dependent role (child or elderly)
        # This is based on what the guardian specified in pending_dependent.relation
        if pending_dependent.relation == "child":
            assign_role_to_user(current_user.id, "child", db)
        elif pending_dependent.relation == "elderly":
            assign_role_to_user(current_user.id, "elderly", db)
        
        # Commit all changes
        db.commit()
        db.refresh(qr_invitation)
        
        print(f"✅ QR scan successful: {guardian.full_name} → {current_user.full_name}")
        
        return ScanQRResponse(
            success=True,
            message=f"Successfully linked with {guardian.full_name}!",
            guardian_name=guardian.full_name,
            dependent_name=pending_dependent.dependent_name,
            relation=pending_dependent.relation,
            age=pending_dependent.age,
            qr_invitation_id=qr_invitation.id
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error scanning QR: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to scan QR code: {str(e)}"
        )


# ================================================
# GET MY GUARDIANS
# ================================================

@router.get("/my-guardians", response_model=List[GuardianDetailResponse])
async def get_my_guardians(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all guardians linked to the current dependent
    Requires: child or elderly role
    """
    try:
        # Verify user has dependent role
        verify_dependent_role(current_user, db)
        
        # Get all relationships where current user is the dependent
        relationships = db.query(GuardianDependent).filter(
            GuardianDependent.dependent_id == current_user.id
        ).all()
        
        result = []
        for rel in relationships:
            guardian_user = db.query(User).filter(
                User.id == rel.guardian_id
            ).first()
            
            if guardian_user:
                result.append(GuardianDetailResponse(
                    id=rel.id,
                    guardian_id=rel.guardian_id,
                    guardian_name=guardian_user.full_name,
                    guardian_email=guardian_user.email,
                    relation=rel.relation,
                    is_primary=rel.is_primary,
                    linked_at=rel.created_at
                ))
        
        print(f"✅ Retrieved {len(result)} guardians for dependent {current_user.id}")
        return result
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching guardians: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch guardians: {str(e)}"
        )


# ================================================
# REMOVE GUARDIAN (Optional - for user to unlink)
# ================================================

@router.delete("/remove-guardian/{relationship_id}")
async def remove_guardian(
    relationship_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Remove a guardian-dependent relationship
    Only the dependent can remove the relationship
    """
    try:
        # Verify user has dependent role
        verify_dependent_role(current_user, db)
        
        # Find the relationship
        relationship = db.query(GuardianDependent).filter(
            GuardianDependent.id == relationship_id,
            GuardianDependent.dependent_id == current_user.id
        ).first()
        
        if not relationship:
            raise HTTPException(
                status_code=404,
                detail="Guardian relationship not found"
            )
        
        # Delete the relationship
        db.delete(relationship)
        db.commit()
        
        print(f"✅ Removed guardian relationship {relationship_id}")
        
        return {
            "success": True,
            "message": "Guardian removed successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error removing guardian: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to remove guardian: {str(e)}"
        )