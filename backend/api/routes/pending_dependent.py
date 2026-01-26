"""
Pending Dependent Routes
Handles guardian-dependent linking workflow via QR codes
"""

from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime

# Schemas
from api.schemas.pending_dependent import (
    PendingDependentCreate,
    PendingDependentResponse,
    PendingDependentWithQR,
    GenerateQRRequest,
    GenerateQRResponse,
    ScanQRRequest,
    ScanQRResponse,
    ApproveQRRequest,
    ApproveQRResponse,
    RejectQRRequest,
    DependentDetailResponse,
    GuardianDetailResponse,
    PendingQRInvitationResponse
)

# Models
from models.user import User
from models.pending_dependent import PendingDependent
from models.qr_invitation import QRInvitation
from models.guardian_dependent import GuardianDependent
from models.user_roles import UserRole
from models.role import Role

# Dependencies
from api.dependencies.auth import get_current_user
from database.connection import get_db

# Router
router = APIRouter()


# ----------------------
# Helper Functions
# ----------------------
def verify_guardian_role(user: User, db: Session):
    """Check if user has guardian role"""
    guardian_role = db.query(Role).filter(Role.role_name == "guardian").first()
    if not guardian_role:
        raise HTTPException(status_code=500, detail="Guardian role not found in system")
    
    has_guardian_role = db.query(UserRole).filter(
        UserRole.user_id == user.id,
        UserRole.role_id == guardian_role.id
    ).first()
    
    if not has_guardian_role:
        raise HTTPException(status_code=403, detail="User does not have guardian role")
    
    return True


def verify_dependent_role(user: User, db: Session):
    """Check if user has child or elderly role"""
    child_role = db.query(Role).filter(Role.role_name == "child").first()
    elderly_role = db.query(Role).filter(Role.role_name == "elderly").first()
    
    if not child_role or not elderly_role:
        raise HTTPException(status_code=500, detail="Dependent roles not found in system")
    
    has_dependent_role = db.query(UserRole).filter(
        UserRole.user_id == user.id,
        UserRole.role_id.in_([child_role.id, elderly_role.id])
    ).first()
    
    if not has_dependent_role:
        raise HTTPException(status_code=403, detail="User does not have dependent role (child or elderly)")
    
    return True


# ----------------------
# STEP 1: Guardian Creates Pending Dependent
# ----------------------
@router.post("/create", response_model=PendingDependentResponse, status_code=status.HTTP_201_CREATED)
async def create_pending_dependent(
    data: PendingDependentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Guardian creates a pending dependent (before QR generation)
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Create pending dependent
    pending_dependent = PendingDependent(
        guardian_id=current_user.id,
        dependent_name=data.dependent_name,
        relation=data.relation,
        age=data.age
    )

    db.add(pending_dependent)
    db.commit()
    db.refresh(pending_dependent)

    return pending_dependent


# ----------------------
# STEP 2: Guardian Generates QR Code
# ----------------------
@router.post("/generate-qr", response_model=GenerateQRResponse)
async def generate_qr_code(
    data: GenerateQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Guardian generates QR code for a pending dependent
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Check if pending dependent exists and belongs to guardian
    pending_dependent = db.query(PendingDependent).filter(
        PendingDependent.id == data.pending_dependent_id,
        PendingDependent.guardian_id == current_user.id
    ).first()

    if not pending_dependent:
        raise HTTPException(status_code=404, detail="Pending dependent not found or not owned by you")

    # Check if active QR already exists
    existing_qr = db.query(QRInvitation).filter(
        QRInvitation.pending_dependent_id == data.pending_dependent_id,
        QRInvitation.status.in_(["pending", "scanned"])
    ).first()

    if existing_qr:
        raise HTTPException(
            status_code=400,
            detail=f"Active QR code already exists with status: {existing_qr.status}"
        )

    # Generate new QR invitation
    qr_token = QRInvitation.generate_token()
    expires_at = QRInvitation.calculate_expiry(days=3)

    qr_invitation = QRInvitation(
        qr_token=qr_token,
        guardian_id=current_user.id,
        pending_dependent_id=data.pending_dependent_id,
        status="pending",
        expires_at=expires_at
    )

    db.add(qr_invitation)
    db.commit()
    db.refresh(qr_invitation)

    return GenerateQRResponse(
        success=True,
        message="QR code generated successfully",
        qr_token=qr_token,
        expires_at=expires_at,
        pending_dependent_id=data.pending_dependent_id
    )


# ----------------------
# STEP 3: Child/Elderly Scans QR Code
# ----------------------
@router.post("/scan-qr", response_model=ScanQRResponse)
async def scan_qr_code(
    data: ScanQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Child/Elderly scans QR code to link with guardian
    Requires: child or elderly role
    """
    # Verify dependent role
    verify_dependent_role(current_user, db)

    # Find QR invitation
    qr_invitation = db.query(QRInvitation).filter(
        QRInvitation.qr_token == data.qr_token
    ).first()

    if not qr_invitation:
        raise HTTPException(status_code=404, detail="Invalid QR code")

    # Check if expired
    if qr_invitation.is_expired():
        qr_invitation.status = "expired"
        db.commit()
        raise HTTPException(status_code=400, detail="QR code has expired")

    # Check if can be scanned
    if not qr_invitation.can_be_scanned():
        raise HTTPException(
            status_code=400,
            detail=f"QR code cannot be scanned. Current status: {qr_invitation.status}"
        )

    # Check if user is trying to scan their own QR (guardian scanning their own code)
    if qr_invitation.guardian_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot scan your own QR code")

    # Update QR invitation with scanned info
    qr_invitation.scanned_by_user_id = current_user.id
    qr_invitation.status = "scanned"
    qr_invitation.scanned_at = datetime.utcnow()

    db.commit()
    db.refresh(qr_invitation)

    # Get pending dependent info
    pending_dependent = db.query(PendingDependent).filter(
        PendingDependent.id == qr_invitation.pending_dependent_id
    ).first()

    # Get guardian info
    guardian = db.query(User).filter(User.id == qr_invitation.guardian_id).first()

    return ScanQRResponse(
        success=True,
        message="QR code scanned successfully. Waiting for guardian approval.",
        guardian_name=guardian.full_name,
        dependent_name=pending_dependent.dependent_name,
        relation=pending_dependent.relation,
        age=pending_dependent.age,
        qr_invitation_id=qr_invitation.id
    )


# ----------------------
# STEP 4: Guardian Approves Scan
# ----------------------
@router.post("/approve", response_model=ApproveQRResponse)
async def approve_qr_scan(
    data: ApproveQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Guardian approves the scanned QR and creates the relationship
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Find QR invitation
    qr_invitation = db.query(QRInvitation).filter(
        QRInvitation.id == data.qr_invitation_id,
        QRInvitation.guardian_id == current_user.id
    ).first()

    if not qr_invitation:
        raise HTTPException(status_code=404, detail="QR invitation not found or not owned by you")

    # Check if already approved
    if qr_invitation.is_approved:
        raise HTTPException(status_code=400, detail="QR invitation already approved")

    # Check if scanned
    if qr_invitation.status != "scanned" or not qr_invitation.scanned_by_user_id:
        raise HTTPException(status_code=400, detail="QR code has not been scanned yet")

    # Get pending dependent
    pending_dependent = db.query(PendingDependent).filter(
        PendingDependent.id == qr_invitation.pending_dependent_id
    ).first()

    if not pending_dependent:
        raise HTTPException(status_code=404, detail="Pending dependent not found")

    # Check if relationship already exists
    existing_relationship = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.dependent_id == qr_invitation.scanned_by_user_id
    ).first()

    if existing_relationship:
        raise HTTPException(status_code=400, detail="Relationship already exists")

    # Check if this will be the first guardian (primary)
    is_primary = not db.query(GuardianDependent).filter(
        GuardianDependent.dependent_id == qr_invitation.scanned_by_user_id
    ).first()

    # Create guardian-dependent relationship
    relationship = GuardianDependent(
        guardian_id=current_user.id,
        dependent_id=qr_invitation.scanned_by_user_id,
        relation=pending_dependent.relation,
        is_primary=is_primary,
        pending_dependent_id=pending_dependent.id
    )

    db.add(relationship)

    # Update QR invitation
    qr_invitation.is_approved = True
    qr_invitation.status = "approved"
    qr_invitation.approved_at = datetime.utcnow()

    db.commit()
    db.refresh(relationship)

    return ApproveQRResponse(
        success=True,
        message=f"Relationship approved. Dependent linked as {'primary' if is_primary else 'secondary'} guardian.",
        relationship_id=relationship.id,
        guardian_id=relationship.guardian_id,
        dependent_id=relationship.dependent_id,
        relation=relationship.relation
    )


# ----------------------
# Guardian Rejects Scan
# ----------------------
@router.post("/reject")
async def reject_qr_scan(
    data: RejectQRRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Guardian rejects the scanned QR
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Find QR invitation
    qr_invitation = db.query(QRInvitation).filter(
        QRInvitation.id == data.qr_invitation_id,
        QRInvitation.guardian_id == current_user.id
    ).first()

    if not qr_invitation:
        raise HTTPException(status_code=404, detail="QR invitation not found or not owned by you")

    # Check if scanned
    if qr_invitation.status != "scanned":
        raise HTTPException(status_code=400, detail="Can only reject scanned QR codes")

    # Update status
    qr_invitation.status = "rejected"
    qr_invitation.is_approved = False

    db.commit()

    return {
        "success": True,
        "message": "QR invitation rejected successfully"
    }


# ----------------------
# Get Guardian's Pending Dependents
# ----------------------
@router.get("/my-pending", response_model=List[PendingDependentWithQR])
async def get_my_pending_dependents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all pending dependents created by the guardian
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Get all pending dependents for this guardian
    pending_dependents = db.query(PendingDependent).filter(
        PendingDependent.guardian_id == current_user.id
    ).all()

    # Enhance with QR info
    result = []
    for pd in pending_dependents:
        qr = db.query(QRInvitation).filter(
            QRInvitation.pending_dependent_id == pd.id,
            QRInvitation.status.in_(["pending", "scanned"])
        ).first()

        result.append(PendingDependentWithQR(
            id=pd.id,
            guardian_id=pd.guardian_id,
            dependent_name=pd.dependent_name,
            relation=pd.relation,
            age=pd.age,
            created_at=pd.created_at,
            has_qr=qr is not None,
            qr_status=qr.status if qr else None,
            qr_token=qr.qr_token if qr and qr.status == "pending" else None
        ))

    return result


# ----------------------
# Get Guardian's Scanned QR Invitations (Pending Approval)
# ----------------------
@router.get("/pending-approvals", response_model=List[PendingQRInvitationResponse])
async def get_pending_approvals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all scanned QR invitations waiting for guardian approval
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Get all scanned QR invitations for this guardian
    qr_invitations = db.query(QRInvitation).filter(
        QRInvitation.guardian_id == current_user.id,
        QRInvitation.status == "scanned"
    ).all()

    result = []
    for qr in qr_invitations:
        pending_dependent = db.query(PendingDependent).filter(
            PendingDependent.id == qr.pending_dependent_id
        ).first()

        scanned_user = db.query(User).filter(
            User.id == qr.scanned_by_user_id
        ).first() if qr.scanned_by_user_id else None

        result.append(PendingQRInvitationResponse(
            qr_invitation_id=qr.id,
            pending_dependent_id=qr.pending_dependent_id,
            dependent_name=pending_dependent.dependent_name,
            relation=pending_dependent.relation,
            age=pending_dependent.age,
            status=qr.status,
            scanned_by_user_id=qr.scanned_by_user_id,
            scanned_by_name=scanned_user.full_name if scanned_user else None,
            scanned_at=qr.scanned_at,
            created_at=qr.created_at,
            expires_at=qr.expires_at
        ))

    return result


# ----------------------
# Get Guardian's Approved Dependents
# ----------------------
@router.get("/my-dependents", response_model=List[DependentDetailResponse])
async def get_my_dependents(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all approved dependents for the guardian
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Get all relationships where user is guardian
    relationships = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id
    ).all()

    result = []
    for rel in relationships:
        dependent_user = db.query(User).filter(User.id == rel.dependent_id).first()
        
        # Try to get age from pending dependent if available
        age = None
        if rel.pending_dependent_id:
            pending = db.query(PendingDependent).filter(
                PendingDependent.id == rel.pending_dependent_id
            ).first()
            if pending:
                age = pending.age

        result.append(DependentDetailResponse(
            id=rel.id,
            dependent_id=rel.dependent_id,
            dependent_name=dependent_user.full_name,
            dependent_email=dependent_user.email,
            relation=rel.relation,
            age=age,
            is_primary=rel.is_primary,
            linked_at=rel.created_at
        ))

    return result


# ----------------------
# Get Dependent's Guardians
# ----------------------
@router.get("/my-guardians", response_model=List[GuardianDetailResponse])
async def get_my_guardians(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get all guardians for the dependent (child/elderly)
    Requires: child or elderly role
    """
    # Verify dependent role
    verify_dependent_role(current_user, db)

    # Get all relationships where user is dependent
    relationships = db.query(GuardianDependent).filter(
        GuardianDependent.dependent_id == current_user.id
    ).all()

    result = []
    for rel in relationships:
        guardian_user = db.query(User).filter(User.id == rel.guardian_id).first()

        result.append(GuardianDetailResponse(
            id=rel.id,
            guardian_id=rel.guardian_id,
            guardian_name=guardian_user.full_name,
            guardian_email=guardian_user.email,
            relation=rel.relation,
            is_primary=rel.is_primary,
            linked_at=rel.created_at
        ))

    return result


# ----------------------
# Delete Pending Dependent
# ----------------------
@router.delete("/{pending_dependent_id}")
async def delete_pending_dependent(
    pending_dependent_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Delete a pending dependent (only if not yet approved)
    Requires: guardian role
    """
    # Verify guardian role
    verify_guardian_role(current_user, db)

    # Find pending dependent
    pending_dependent = db.query(PendingDependent).filter(
        PendingDependent.id == pending_dependent_id,
        PendingDependent.guardian_id == current_user.id
    ).first()

    if not pending_dependent:
        raise HTTPException(status_code=404, detail="Pending dependent not found or not owned by you")

    # Check if any approved relationships exist
    approved_qr = db.query(QRInvitation).filter(
        QRInvitation.pending_dependent_id == pending_dependent_id,
        QRInvitation.is_approved == True
    ).first()

    if approved_qr:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete pending dependent with approved relationships"
        )

    # Delete associated QR invitations first (cascade should handle this, but explicit is safer)
    db.query(QRInvitation).filter(
        QRInvitation.pending_dependent_id == pending_dependent_id
    ).delete()

    # Delete pending dependent
    db.delete(pending_dependent)
    db.commit()

    return {
        "success": True,
        "message": "Pending dependent deleted successfully"
    }