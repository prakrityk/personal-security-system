"""
Guardian Routes
Handles guardian-related operations: pending dependents, QR generation, approvals
"""

from datetime import datetime, timedelta, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

# Schemas
from api.schemas.pending_dependent import (
    PendingDependentCreate,
    PendingDependentResponse,
    PendingDependentWithQR,
    GenerateQRRequest,
    GenerateQRResponse,
    ApproveQRRequest,
    ApproveQRResponse,
    RejectQRRequest,
    DependentDetailResponse,
    PendingQRInvitationResponse
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

router = APIRouter()


# ================================================
# HELPER FUNCTIONS
# ================================================

def verify_guardian_role(current_user: User, db: Session):
    """Verify that the current user has the guardian role"""
    user_roles = db.query(Role).join(UserRole).filter(
        UserRole.user_id == current_user.id
    ).all()
    
    is_guardian = any(role.role_name == "guardian" for role in user_roles)
    
    if not is_guardian:
        raise HTTPException(
            status_code=403,
            detail="User must have guardian role to perform this action"
        )
    
    return True


# ================================================
# PENDING DEPENDENTS CRUD
# ================================================

@router.post("/pending-dependents", response_model=PendingDependentResponse)
async def create_pending_dependent(
    dependent_data: PendingDependentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a new pending dependent
    Guardian creates a dependent profile before QR generation
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Create pending dependent
        new_dependent = PendingDependent(
            guardian_id=current_user.id,
            dependent_name=dependent_data.dependent_name,
            relation=dependent_data.relation,
            age=dependent_data.Age
        )
        
        db.add(new_dependent)
        db.commit()
        db.refresh(new_dependent)
        
        print(f"✅ Pending dependent created: {new_dependent.dependent_name} (ID: {new_dependent.id})")
        
        return PendingDependentResponse(
            id=new_dependent.id,
            guardian_id=new_dependent.guardian_id,
            dependent_name=new_dependent.dependent_name,
            relation=new_dependent.relation,
            Age=new_dependent.age,
            created_at=new_dependent.created_at
        )
    
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating pending dependent: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create pending dependent: {str(e)}"
        )


@router.get("/pending-dependents", response_model=List[PendingDependentWithQR])
async def get_pending_dependents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all pending dependents for the current guardian
    Includes QR status information
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Get all pending dependents for this guardian
        pending_dependents = db.query(PendingDependent).filter(
            PendingDependent.guardian_id == current_user.id
        ).order_by(desc(PendingDependent.created_at)).all()
        
        result = []
        for dependent in pending_dependents:
            # Check if QR exists for this dependent
            qr_invitation = db.query(QRInvitation).filter(
                QRInvitation.pending_dependent_id == dependent.id
            ).order_by(desc(QRInvitation.created_at)).first()
            
            has_qr = qr_invitation is not None
            qr_status = qr_invitation.status if qr_invitation else None
            qr_token = qr_invitation.qr_token if qr_invitation else None
            
            result.append(PendingDependentWithQR(
                id=dependent.id,
                guardian_id=dependent.guardian_id,
                dependent_name=dependent.dependent_name,
                relation=dependent.relation,
                Age=dependent.age,
                created_at=dependent.created_at,
                has_qr=has_qr,
                qr_status=qr_status,
                qr_token=qr_token
            ))
        
        print(f"✅ Retrieved {len(result)} pending dependents for guardian {current_user.id}")
        return result
    
    except Exception as e:
        print(f"❌ Error fetching pending dependents: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch pending dependents: {str(e)}"
        )


@router.delete("/pending-dependents/{pending_dependent_id}")
async def delete_pending_dependent(
    pending_dependent_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a pending dependent
    Also deletes associated QR invitations (cascade)
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Find the dependent
        dependent = db.query(PendingDependent).filter(
            PendingDependent.id == pending_dependent_id,
            PendingDependent.guardian_id == current_user.id
        ).first()
        
        if not dependent:
            raise HTTPException(
                status_code=404,
                detail="Pending dependent not found"
            )
        
        # Delete (QR invitations will cascade delete)
        db.delete(dependent)
        db.commit()
        
        print(f"✅ Deleted pending dependent {pending_dependent_id}")
        
        return {
            "success": True,
            "message": "Pending dependent deleted successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting pending dependent: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete pending dependent: {str(e)}"
        )


# ================================================
# QR CODE GENERATION
# ================================================

@router.post("/generate-qr", response_model=GenerateQRResponse)
async def generate_qr_code(
    request: GenerateQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Generate a QR code for a pending dependent
    Creates a QR invitation with unique token
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Verify pending dependent exists and belongs to guardian
        dependent = db.query(PendingDependent).filter(
            PendingDependent.id == request.pending_dependent_id,
            PendingDependent.guardian_id == current_user.id
        ).first()
        
        if not dependent:
            raise HTTPException(
                status_code=404,
                detail="Pending dependent not found"
            )
        
        # Check if QR already exists and is still valid
        existing_qr = db.query(QRInvitation).filter(
            QRInvitation.pending_dependent_id == request.pending_dependent_id,
            QRInvitation.status == "pending"
        ).first()
        
        if existing_qr and not existing_qr.is_expired():
            # Return existing QR if still valid
            return GenerateQRResponse(
                success=True,
                message="QR code already exists",
                qr_token=existing_qr.qr_token,
                expires_at=existing_qr.expires_at,
                pending_dependent_id=request.pending_dependent_id
            )
        
        # Generate new QR invitation
        qr_token = QRInvitation.generate_token()
        expires_at = QRInvitation.calculate_expiry(days=3)
        
        new_qr = QRInvitation(
            qr_token=qr_token,
            guardian_id=current_user.id,
            pending_dependent_id=request.pending_dependent_id,
            status="pending",
            expires_at=expires_at
        )
        
        db.add(new_qr)
        db.commit()
        db.refresh(new_qr)
        
        print(f"✅ QR code generated for dependent {dependent.dependent_name}")
        
        return GenerateQRResponse(
            success=True,
            message="QR code generated successfully",
            qr_token=qr_token,
            expires_at=expires_at,
            pending_dependent_id=request.pending_dependent_id
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error generating QR code: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate QR code: {str(e)}"
        )


@router.get("/qr-invitation/{pending_dependent_id}")
async def get_qr_invitation(
    pending_dependent_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get QR invitation details for a pending dependent
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Verify ownership
        dependent = db.query(PendingDependent).filter(
            PendingDependent.id == pending_dependent_id,
            PendingDependent.guardian_id == current_user.id
        ).first()
        
        if not dependent:
            raise HTTPException(
                status_code=404,
                detail="Pending dependent not found"
            )
        
        # Get QR invitation
        qr_invitation = db.query(QRInvitation).filter(
            QRInvitation.pending_dependent_id == pending_dependent_id
        ).order_by(desc(QRInvitation.created_at)).first()
        
        if not qr_invitation:
            raise HTTPException(
                status_code=404,
                detail="QR invitation not found"
            )
        
        return {
            "id": qr_invitation.id,
            "qr_token": qr_invitation.qr_token,
            "status": qr_invitation.status,
            "created_at": qr_invitation.created_at,
            "expires_at": qr_invitation.expires_at,
            "scanned_at": qr_invitation.scanned_at,
            "is_expired": qr_invitation.is_expired()
        }
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching QR invitation: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch QR invitation: {str(e)}"
        )


# ================================================
# PENDING QR INVITATIONS (Scanned but not approved)
# ================================================

@router.get("/pending-qr-invitations", response_model=List[PendingQRInvitationResponse])
async def get_pending_qr_invitations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all QR invitations that have been scanned but not yet approved/rejected
    Guardian uses this to see who has scanned their QR codes
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Get scanned but not approved QR invitations
        qr_invitations = db.query(QRInvitation).filter(
            QRInvitation.guardian_id == current_user.id,
            QRInvitation.status == "scanned",
            QRInvitation.is_approved == False
        ).order_by(desc(QRInvitation.scanned_at)).all()
        
        result = []
        for qr in qr_invitations:
            # Get pending dependent info
            pending_dependent = db.query(PendingDependent).filter(
                PendingDependent.id == qr.pending_dependent_id
            ).first()
            
            # Get scanned user info
            scanned_by_user = None
            scanned_by_name = None
            if qr.scanned_by_user_id:
                scanned_by_user = db.query(User).filter(
                    User.id == qr.scanned_by_user_id
                ).first()
                scanned_by_name = scanned_by_user.full_name if scanned_by_user else None
            
            if pending_dependent:
                result.append(PendingQRInvitationResponse(
                    qr_invitation_id=qr.id,
                    pending_dependent_id=pending_dependent.id,
                    dependent_name=pending_dependent.dependent_name,
                    relation=pending_dependent.relation,
                    Age=pending_dependent.age,
                    status=qr.status,
                    scanned_by_user_id=qr.scanned_by_user_id,
                    scanned_by_name=scanned_by_name,
                    scanned_at=qr.scanned_at,
                    created_at=qr.created_at,
                    expires_at=qr.expires_at
                ))
        
        return result
    
    except Exception as e:
        print(f"❌ Error fetching pending QR invitations: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch pending QR invitations: {str(e)}"
        )


# ================================================
# APPROVE/REJECT QR INVITATIONS
# ================================================

@router.post("/approve-qr", response_model=ApproveQRResponse)
async def approve_qr_invitation(
    request: ApproveQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Approve a scanned QR invitation
    Creates the guardian-dependent relationship
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Get QR invitation
        qr_invitation = db.query(QRInvitation).filter(
            QRInvitation.id == request.qr_invitation_id,
            QRInvitation.guardian_id == current_user.id,
            QRInvitation.status == "scanned"
        ).first()
        
        if not qr_invitation:
            raise HTTPException(
                status_code=404,
                detail="QR invitation not found or already processed"
            )
        
        if not qr_invitation.scanned_by_user_id:
            raise HTTPException(
                status_code=400,
                detail="QR has not been scanned yet"
            )
        
        # Get pending dependent
        pending_dependent = db.query(PendingDependent).filter(
            PendingDependent.id == qr_invitation.pending_dependent_id
        ).first()
        
        if not pending_dependent:
            raise HTTPException(
                status_code=404,
                detail="Pending dependent not found"
            )
        
        # Check if relationship already exists
        existing_relationship = db.query(GuardianDependent).filter(
            GuardianDependent.guardian_id == current_user.id,
            GuardianDependent.dependent_id == qr_invitation.scanned_by_user_id
        ).first()
        
        if existing_relationship:
            # Update QR status
            qr_invitation.status = "approved"
            qr_invitation.is_approved = True
            qr_invitation.approved_at = datetime.now(timezone.utc)
            db.commit()
            
            return ApproveQRResponse(
                success=True,
                message="Relationship already exists",
                relationship_id=existing_relationship.id,
                guardian_id=existing_relationship.guardian_id,
                dependent_id=existing_relationship.dependent_id,
                relation=existing_relationship.relation
            )
        
        # Create guardian-dependent relationship
        new_relationship = GuardianDependent(
            guardian_id=current_user.id,
            dependent_id=qr_invitation.scanned_by_user_id,
            relation=pending_dependent.relation,
            is_primary=True,  # First guardian is primary
            pending_dependent_id=pending_dependent.id
        )
        
        db.add(new_relationship)
        
        # Update QR invitation status
        qr_invitation.status = "approved"
        qr_invitation.is_approved = True
        qr_invitation.approved_at = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(new_relationship)
        
        print(f"✅ Guardian-dependent relationship created: {current_user.id} → {qr_invitation.scanned_by_user_id}")
        
        return ApproveQRResponse(
            success=True,
            message="Relationship created successfully",
            relationship_id=new_relationship.id,
            guardian_id=new_relationship.guardian_id,
            dependent_id=new_relationship.dependent_id,
            relation=new_relationship.relation
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error approving QR invitation: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to approve QR invitation: {str(e)}"
        )


@router.post("/reject-qr")
async def reject_qr_invitation(
    request: RejectQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Reject a scanned QR invitation
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Get QR invitation
        qr_invitation = db.query(QRInvitation).filter(
            QRInvitation.id == request.qr_invitation_id,
            QRInvitation.guardian_id == current_user.id
        ).first()
        
        if not qr_invitation:
            raise HTTPException(
                status_code=404,
                detail="QR invitation not found"
            )
        
        # Update status
        qr_invitation.status = "rejected"
        db.commit()
        
        print(f"✅ QR invitation {request.qr_invitation_id} rejected")
        
        return {
            "success": True,
            "message": "QR invitation rejected"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error rejecting QR invitation: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to reject QR invitation: {str(e)}"
        )


# ================================================
# MY DEPENDENTS (Approved relationships)
# ================================================

@router.get("/my-dependents", response_model=List[DependentDetailResponse])
async def get_my_dependents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all approved dependents for the current guardian
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)
    
    try:
        # Get all guardian-dependent relationships
        relationships = db.query(GuardianDependent).filter(
            GuardianDependent.guardian_id == current_user.id
        ).order_by(desc(GuardianDependent.created_at)).all()
        
        result = []
        for rel in relationships:
            dependent_user = db.query(User).filter(
                User.id == rel.dependent_id
            ).first()
            
            if dependent_user:
                # Get age from pending dependent if available
                age = None
                if rel.pending_dependent_id:
                    pending = db.query(PendingDependent).filter(
                        PendingDependent.id == rel.pending_dependent_id
                    ).first()
                    age = pending.age if pending else None
                
                result.append(DependentDetailResponse(
                    id=rel.id,
                    dependent_id=rel.dependent_id,
                    dependent_name=dependent_user.full_name,
                    dependent_email=dependent_user.email,
                    relation=rel.relation,
                    Age=age,
                    is_primary=rel.is_primary,
                    linked_at=rel.created_at
                ))
        
        print(f"✅ Retrieved {len(result)} dependents for guardian {current_user.id}")
        return result
    
    except Exception as e:
        print(f"❌ Error fetching dependents: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch dependents: {str(e)}"
        )