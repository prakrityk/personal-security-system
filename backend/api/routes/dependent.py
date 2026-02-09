"""
Dependent Routes - CORRECTED WITH AUTO-CONTACT INTEGRATION
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
from models.dependent_safety_settings import DependentSafetySettings
from models.role import Role
from models.user_roles import UserRole

# Dependencies
from api.utils.auth_utils import get_current_user_with_roles
from database.connection import get_db

# ✅ CRITICAL: Import auto-contact hooks
from api.routes.guardian_auto_contacts import (
    on_guardian_relationship_created,
    on_guardian_relationship_revoked,
)

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
    role = db.query(Role).filter(Role.role_name == role_name).first()
    
    if not role:
        raise HTTPException(
            status_code=500,
            detail=f"Role '{role_name}' not found in system"
        )
    
    existing = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role.id
    ).first()
    
    if not existing:
        user_role = UserRole(user_id=user_id, role_id=role.id)
        db.add(user_role)
        db.commit()
        print(f"✅ Assigned role '{role_name}' to user {user_id}")
    else:
        print(f"ℹ️  User {user_id} already has role '{role_name}'")


# ================================================
# SCAN QR CODE (FIXED)
# ================================================

@router.post("/scan-qr", response_model=ScanQRResponse)
async def scan_qr_code(
    request: ScanQRRequest,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """
    Dependent scans QR code to link with guardian
    This automatically creates the guardian-dependent relationship
    """
    try:
        print(f"📱 User {current_user.id} scanning QR: {request.qr_token}")
        
        verify_dependent_role(current_user, db)
        
        qr_invitation = db.query(QRInvitation).filter(
            QRInvitation.qr_token == request.qr_token
        ).first()
        
        if not qr_invitation:
            raise HTTPException(
                status_code=404,
                detail="Invalid QR code"
            )
        
        if qr_invitation.is_expired():
            qr_invitation.status = "expired"
            db.commit()
            raise HTTPException(
                status_code=400,
                detail="QR code has expired. Please ask your guardian for a new one."
            )
        
        if qr_invitation.status not in ["pending", "scanned"]:
            raise HTTPException(
                status_code=400,
                detail=f"QR code has already been {qr_invitation.status}"
            )
        
        if qr_invitation.guardian_id == current_user.id:
            raise HTTPException(
                status_code=400,
                detail="You cannot scan your own QR code"
            )
        
        pending_dependent = db.query(PendingDependent).filter(
            PendingDependent.id == qr_invitation.pending_dependent_id
        ).first()
        
        if not pending_dependent:
            raise HTTPException(
                status_code=404,
                detail="Pending dependent information not found"
            )
        
        guardian = db.query(User).filter(
            User.id == qr_invitation.guardian_id
        ).first()
        
        if not guardian:
            raise HTTPException(
                status_code=404,
                detail="Guardian not found"
            )
        
        # Update QR invitation status
        qr_invitation.scanned_by_user_id = current_user.id
        qr_invitation.status = "approved"
        qr_invitation.is_approved = True
        qr_invitation.scanned_at = datetime.now(timezone.utc)
        qr_invitation.approved_at = datetime.now(timezone.utc)
        
        # Check if relationship already exists
        existing_relationship = db.query(GuardianDependent).filter(
            GuardianDependent.guardian_id == guardian.id,
            GuardianDependent.dependent_id == current_user.id
        ).first()
        
        new_relationship = None
        if not existing_relationship:
            # Create guardian-dependent relationship
            new_relationship = GuardianDependent(
                guardian_id=guardian.id,
                dependent_id=current_user.id,
                relation=pending_dependent.relation,
                is_primary=True,
                guardian_type="primary",  # ✅ Make sure this is set
                pending_dependent_id=pending_dependent.id
            )
            db.add(new_relationship)
            db.commit()
            db.refresh(new_relationship)
            print(f"✅ Created guardian-dependent relationship: {guardian.id} → {current_user.id}")
            
            # ✅ AUTO-SYNC: Create emergency contact for dependent
            try:
                on_guardian_relationship_created(db, new_relationship)
                print(f"✅ Auto-created emergency contact for primary guardian")
            except Exception as e:
                print(f"⚠️ Warning: Could not auto-create emergency contact: {e}")
                # Don't fail the main operation
        else:
            print(f"ℹ️  Guardian-dependent relationship already exists")
        
        # Ensure user has the correct dependent role
        if pending_dependent.relation == "child":
            assign_role_to_user(current_user.id, "child", db)
        elif pending_dependent.relation == "elderly":
            assign_role_to_user(current_user.id, "elderly", db)
        
        # Commit QR status update
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

# @router.get("/my-guardians", response_model=List[GuardianDetailResponse])
# async def get_my_guardians(
#     current_user: User = Depends(get_current_user_with_roles),
#     db: Session = Depends(get_db)
# ):
#     """Get all guardians linked to the current dependent"""
#     try:
#         verify_dependent_role(current_user, db)
        
#         relationships = db.query(GuardianDependent).filter(
#             GuardianDependent.dependent_id == current_user.id
#         ).all()
        
#         result = []
#         for rel in relationships:
#             guardian_user = db.query(User).filter(
#                 User.id == rel.guardian_id
#             ).first()
            
#             if guardian_user:
#                 result.append(GuardianDetailResponse(
#                     id=rel.id,
#                     guardian_id=rel.guardian_id,
#                     guardian_name=guardian_user.full_name,
#                     guardian_email=guardian_user.email,
#                     relation=rel.relation,
#                     is_primary=rel.is_primary,
#                     linked_at=rel.created_at
#                 ))
        
#         print(f"✅ Retrieved {len(result)} guardians for dependent {current_user.id}")
#         return result
    
#     except HTTPException:
#         raise
#     except Exception as e:
#         print(f"❌ Error fetching guardians: {e}")
#         raise HTTPException(
#             status_code=500,
#             detail=f"Failed to fetch guardians: {str(e)}"
#         )

@router.get("/my-guardians", response_model=List[GuardianDetailResponse])
async def get_my_guardians(
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Get all guardians linked to the current dependent"""
    try:
        verify_dependent_role(current_user, db)
        
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
                    phone_number=guardian_user.phone_number,
                    profile_picture=guardian_user.profile_picture,
                    relation=rel.relation,
                    is_primary=rel.is_primary,
                    guardian_type=rel.guardian_type,  # ✅ ADD THIS
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
# REMOVE GUARDIAN (FIXED)
# ================================================

# ================================================
# MY SAFETY SETTINGS (dependent device reads guardian-configured settings)
# ================================================

@router.get("/my-safety-settings")
async def get_my_safety_settings(
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db),
):
    """
    Get the current user's (dependent's) resolved safety settings.
    These are configured by the primary guardian; the dependent's app
    uses them for motion detection etc.
    """
    verify_dependent_role(current_user, db)

    row = db.query(DependentSafetySettings).filter(
        DependentSafetySettings.dependent_id == current_user.id
    ).first()

    if not row:
        # Return defaults if no row yet (primary may not have set any)
        return {
            "live_location": False,
            "audio_recording": False,
            "motion_detection": False,
            "auto_recording": False,
        }

    return {
        "live_location": row.live_location,
        "audio_recording": row.audio_recording,
        "motion_detection": row.motion_detection,
        "auto_recording": row.auto_recording,
    }


@router.delete("/remove-guardian/{relationship_id}")
async def remove_guardian(
    relationship_id: int,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """
    Remove a guardian-dependent relationship
    Only the dependent can remove the relationship
    """
    try:
        verify_dependent_role(current_user, db)
        
        relationship = db.query(GuardianDependent).filter(
            GuardianDependent.id == relationship_id,
            GuardianDependent.dependent_id == current_user.id
        ).first()
        
        if not relationship:
            raise HTTPException(
                status_code=404,
                detail="Guardian relationship not found"
            )
        
        # ✅ AUTO-CLEANUP: Remove emergency contact BEFORE deleting relationship
        try:
            on_guardian_relationship_revoked(db, relationship)
            print(f"✅ Removed auto emergency contact for revoked guardian")
        except Exception as e:
            print(f"⚠️ Warning: Could not remove emergency contact: {e}")
            # Don't fail the main operation
        
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