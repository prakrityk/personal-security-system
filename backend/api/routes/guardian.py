"""
Guardian Routes - CORRECTED WITH AUTO-CONTACT INTEGRATION
Handles guardian-related operations: pending dependents, QR generation, approvals, AND collaborator management
"""

from datetime import datetime, timedelta, timezone
from typing import List
import uuid
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

# Collaborator schemas
from api.schemas.collaborator import (
    CreateCollaboratorInvitationRequest,
    CollaboratorInvitationResponse,
    ValidateInvitationRequest,
    ValidateInvitationResponse,
    AcceptInvitationRequest,
    AcceptInvitationResponse,
    CollaboratorInfo,
    PendingInvitationInfo,
)

# Models
from models.user import User
from models.pending_dependent import PendingDependent
from models.qr_invitation import QRInvitation
from models.guardian_dependent import GuardianDependent
from models.role import Role
from models.user_roles import UserRole
from models.collaborator_invitation import CollaboratorInvitation

# Dependencies
from api.dependencies.auth import get_current_user
from database.connection import get_db

# ✅ CRITICAL: Import auto-contact hooks
from api.routes.guardian_auto_contacts import (
    on_guardian_relationship_created,
    on_guardian_relationship_revoked,
)

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


def verify_primary_guardian(current_user: User, dependent_id: int, db: Session):
    """Verify that current user is primary guardian for dependent"""
    relationship = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.dependent_id == dependent_id,
        GuardianDependent.is_primary == True,
        GuardianDependent.guardian_type == "primary"
    ).first()
    
    if not relationship:
        raise HTTPException(
            status_code=403,
            detail="Only primary guardian can perform this action"
        )
    
    return relationship


def verify_any_guardian(current_user: User, dependent_id: int, db: Session):
    """Verify that current user is any guardian (primary or collaborator)"""
    relationship = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.dependent_id == dependent_id
    ).first()
    
    if not relationship:
        raise HTTPException(
            status_code=403,
            detail="User must be a guardian of this dependent"
        )
    
    return relationship


# ================================================
# PENDING DEPENDENTS CRUD
# ================================================

@router.post("/pending-dependents", response_model=PendingDependentResponse)
async def create_pending_dependent(
    dependent_data: PendingDependentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new pending dependent"""
    verify_guardian_role(current_user, db)
    
    try:
        new_dependent = PendingDependent(
            guardian_id=current_user.id,
            dependent_name=dependent_data.dependent_name,
            relation=dependent_data.relation,
            age=dependent_data.age
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
            age=new_dependent.age,
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
                age=dependent.age,
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
                    age=pending_dependent.age,
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
            guardian_type="primary",  # 🆕 Set as primary type
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
# GET MY DEPENDENTS (ADD THIS TO guardian.py)
# ================================================
# Add this endpoint after your helper functions and before collaborator endpoints

@router.get("/my-dependents", response_model=List[DependentDetailResponse])
async def get_my_dependents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all dependents for the current guardian (both primary and collaborator)
    
    Returns:
    - List of dependents with relationship details
    - Works for both primary guardians and collaborators
    """
    try:
        print(f"📥 Fetching dependents for guardian {current_user.id}")
        
        # Get all relationships where current user is a guardian
        relationships = db.query(GuardianDependent).filter(
            GuardianDependent.guardian_id == current_user.id
        ).all()
        
        result = []
        for rel in relationships:
            # Get dependent user details
            dependent_user = db.query(User).filter(
                User.id == rel.dependent_id
            ).first()
            
            if dependent_user:
                # Get pending dependent info if available
                age = None
                if rel.pending_dependent_id:
                    pending = db.query(PendingDependent).filter(
                        PendingDependent.id == rel.pending_dependent_id
                    ).first()
                    if pending:
                        age = pending.age
                
                result.append(DependentDetailResponse(
                    id=rel.id,  # relationship_id
                    dependent_id=rel.dependent_id,
                    dependent_name=dependent_user.full_name,
                    dependent_email=dependent_user.email,
                    relation=rel.relation,
                    age=age,
                    is_primary=rel.is_primary,
                    guardian_type=rel.guardian_type,  # "primary" or "collaborator"
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
# ... (Keep all other endpoints from your original file until accept_invitation)


# ================================================
# COLLABORATOR INVITATION - ACCEPT (FIXED)
# ================================================
# ================================================
# 🆕 COLLABORATOR ENDPOINTS (NEW)
# ================================================

@router.post("/invite-collaborator", response_model=CollaboratorInvitationResponse)
async def create_collaborator_invitation(
    request: CreateCollaboratorInvitationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Primary guardian creates invitation for collaborator"""
    verify_guardian_role(current_user, db)
    verify_primary_guardian(current_user, request.dependent_id, db)
    
    dependent = db.query(User).filter(User.id == request.dependent_id).first()
    if not dependent:
        raise HTTPException(status_code=404, detail="Dependent not found")
    
    invitation_code = str(uuid.uuid4()).replace('-', '')[:16].upper()
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)
    
    new_invitation = CollaboratorInvitation(
        primary_guardian_id=current_user.id,
        dependent_id=request.dependent_id,
        invitation_code=invitation_code,
        status="pending",
        expires_at=expires_at
    )
    
    db.add(new_invitation)
    db.commit()
    db.refresh(new_invitation)
    
    print(f"✅ Collaborator invitation created: {invitation_code}")
    
    return CollaboratorInvitationResponse(
        id=new_invitation.id,
        invitation_code=invitation_code,
        dependent_id=request.dependent_id,
        dependent_name=dependent.full_name,
        expires_at=expires_at,
        status="pending",
        qr_data=f"COLLAB:{invitation_code}"
    )


@router.post("/validate-invitation", response_model=ValidateInvitationResponse)
async def validate_invitation(
    request: ValidateInvitationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Check if invitation code is valid and not expired"""
    verify_guardian_role(current_user, db)
    
    code = request.invitation_code.replace("COLLAB:", "").strip()
    invitation = db.query(CollaboratorInvitation).filter(
        CollaboratorInvitation.invitation_code == code
    ).first()
    
    if not invitation:
        return ValidateInvitationResponse(valid=False, message="Invalid invitation code")
    
    if invitation.status == "accepted":
        return ValidateInvitationResponse(valid=False, message="This invitation has already been used")
    
    if invitation.status == "cancelled":
        return ValidateInvitationResponse(valid=False, message="This invitation has been cancelled")
    
    if invitation.is_expired():
        invitation.status = "expired"
        db.commit()
        return ValidateInvitationResponse(valid=False, message="This invitation has expired")
    
    if invitation.primary_guardian_id == current_user.id:
        return ValidateInvitationResponse(valid=False, message="You cannot accept your own invitation")
    
    existing = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.dependent_id == invitation.dependent_id
    ).first()
    
    if existing:
        return ValidateInvitationResponse(valid=False, message="You are already a guardian for this dependent")
    
    dependent = db.query(User).filter(User.id == invitation.dependent_id).first()
    primary_guardian = db.query(User).filter(User.id == invitation.primary_guardian_id).first()
    
    if not dependent or not primary_guardian:
        return ValidateInvitationResponse(valid=False, message="Information not found")
    
    primary_rel = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == invitation.primary_guardian_id,
        GuardianDependent.dependent_id == invitation.dependent_id,
        GuardianDependent.is_primary == True
    ).first()
    
    age, relation = None, None
    if primary_rel and primary_rel.pending_dependent_id:
        pending = db.query(PendingDependent).filter(
            PendingDependent.id == primary_rel.pending_dependent_id
        ).first()
        if pending:
            age, relation = pending.age, pending.relation
    
    return ValidateInvitationResponse(
        valid=True,
        message="Invitation is valid",
        dependent_id=dependent.id,
        dependent_name=dependent.full_name,
        dependent_age=age,
        relation=relation,
        primary_guardian_name=primary_guardian.full_name,
        expires_at=invitation.expires_at
    )


@router.post("/accept-invitation", response_model=AcceptInvitationResponse)
async def accept_invitation(
    request: AcceptInvitationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Collaborator accepts invitation and creates relationship"""
    verify_guardian_role(current_user, db)
    
    code = request.invitation_code.replace("COLLAB:", "").strip()
    invitation = db.query(CollaboratorInvitation).filter(
        CollaboratorInvitation.invitation_code == code,
        CollaboratorInvitation.status == "pending"
    ).first()
    
    if not invitation:
        raise HTTPException(status_code=404, detail="Invalid or already used invitation code")
    
    if invitation.is_expired():
        invitation.status = "expired"
        db.commit()
        raise HTTPException(status_code=400, detail="This invitation has expired")
    
    if invitation.primary_guardian_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot accept your own invitation")
    
    existing = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.dependent_id == invitation.dependent_id
    ).first()
    
    if existing:
        invitation.status = "accepted"
        invitation.collaborator_guardian_id = current_user.id
        invitation.accepted_at = datetime.now(timezone.utc)
        db.commit()
        raise HTTPException(status_code=400, detail="You are already a guardian for this dependent")
    
    dependent = db.query(User).filter(User.id == invitation.dependent_id).first()
    if not dependent:
        raise HTTPException(status_code=404, detail="Dependent not found")
    
    primary_rel = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == invitation.primary_guardian_id,
        GuardianDependent.dependent_id == invitation.dependent_id,
        GuardianDependent.is_primary == True
    ).first()
    
    relation = primary_rel.relation if primary_rel else "child"
    
    # Create collaborator relationship
    new_relationship = GuardianDependent(
        guardian_id=current_user.id,
        dependent_id=invitation.dependent_id,
        relation=relation,
        is_primary=False,
        guardian_type="collaborator",
        pending_dependent_id=None
    )
    
    db.add(new_relationship)
    invitation.status = "accepted"
    invitation.collaborator_guardian_id = current_user.id
    invitation.accepted_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(new_relationship)
    
    # ✅ AUTO-SYNC: Create emergency contact for dependent
    try:
        on_guardian_relationship_created(db, new_relationship)
        print(f"✅ Auto-created emergency contact for collaborator")
    except Exception as e:
        print(f"⚠️ Warning: Could not auto-create emergency contact: {e}")
        # Don't fail the main operation
    
    print(f"✅ Collaborator relationship created: {current_user.id} → {invitation.dependent_id}")
    
    return AcceptInvitationResponse(
        success=True,
        message=f"Successfully joined as collaborator guardian for {dependent.full_name}",
        relationship_id=new_relationship.id,
        guardian_id=current_user.id,
        dependent_id=invitation.dependent_id,
        dependent_name=dependent.full_name,
        relation=relation,
        guardian_type="collaborator"
    )

@router.get("/dependent/{dependent_id}/collaborators", response_model=List[CollaboratorInfo])
async def get_collaborators(
    dependent_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all collaborator guardians for a dependent (Primary guardian only)"""
    verify_primary_guardian(current_user, dependent_id, db)
    
    collaborators = db.query(GuardianDependent).filter(
        GuardianDependent.dependent_id == dependent_id,
        GuardianDependent.guardian_type == "collaborator"
    ).all()
    
    result = []
    for rel in collaborators:
        guardian = db.query(User).filter(User.id == rel.guardian_id).first()
        if guardian:
            result.append(CollaboratorInfo(
                relationship_id=rel.id,
                guardian_id=rel.guardian_id,
                guardian_name=guardian.full_name,
                guardian_email=guardian.email,
                joined_at=rel.created_at,
                guardian_type="collaborator"
            ))
    
    print(f"✅ Found {len(result)} collaborators")
    return result


@router.get("/dependent/{dependent_id}/pending-invitations", response_model=List[PendingInvitationInfo])
async def get_pending_invitations(
    dependent_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all pending collaborator invitations (Primary guardian only)"""
    verify_primary_guardian(current_user, dependent_id, db)
    
    invitations = db.query(CollaboratorInvitation).filter(
        CollaboratorInvitation.dependent_id == dependent_id,
        CollaboratorInvitation.primary_guardian_id == current_user.id,
        CollaboratorInvitation.status == "pending"
    ).all()
    
    result = []
    for invitation in invitations:
        if invitation.is_expired():
            invitation.status = "expired"
            db.commit()
        else:
            result.append(PendingInvitationInfo(
                id=invitation.id,
                invitation_code=invitation.invitation_code,
                created_at=invitation.created_at,
                expires_at=invitation.expires_at,
                status=invitation.status
            ))
    
    print(f"✅ Found {len(result)} pending invitations")
    return result



# ... (Keep get_collaborators and get_pending_invitations as-is)


# ================================================
# REVOKE COLLABORATOR (FIXED)
# ================================================

@router.delete("/collaborator/{relationship_id}")
async def revoke_collaborator(
    relationship_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Primary guardian removes collaborator access"""
    relationship = db.query(GuardianDependent).filter(
        GuardianDependent.id == relationship_id
    ).first()
    
    if not relationship:
        raise HTTPException(status_code=404, detail="Relationship not found")
    
    verify_primary_guardian(current_user, relationship.dependent_id, db)
    
    if relationship.guardian_type != "collaborator":
        raise HTTPException(status_code=400, detail="Can only revoke collaborator access")
    
    # ✅ AUTO-CLEANUP: Remove emergency contact BEFORE deleting relationship
    try:
        on_guardian_relationship_revoked(db, relationship)
        print(f"✅ Removed auto emergency contact for revoked collaborator")
    except Exception as e:
        print(f"⚠️ Warning: Could not remove emergency contact: {e}")
        # Don't fail the main operation
    
    db.delete(relationship)
    db.commit()
    
    print(f"✅ Collaborator access revoked for relationship {relationship_id}")
    
    return {"success": True, "message": "Collaborator access revoked successfully"}