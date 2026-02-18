"""
Backend Endpoint: Auto-populate Guardian Contacts as Dependent Emergency Contacts
CORRECTED VERSION with proper imports
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

# ✅ FIXED IMPORTS - Use relative imports based on your project structure
from database.connection import get_db
from models.user import User
from models.emergency_contact import EmergencyContact
from models.guardian_dependent import GuardianDependent
from api.utils.auth_utils import get_current_user_with_roles


router = APIRouter(prefix="", tags=["Emergency Contacts - Auto Guardian"])


# ================================================
# HELPER FUNCTIONS
# ================================================

def sync_guardian_contacts_for_dependent(
    db: Session,
    dependent_id: int,
    guardian_user_id: int,
    relationship_id: int,
    is_primary: bool = False
) -> EmergencyContact:
    """
    Create or update an emergency contact for a dependent based on guardian info
    
    Args:
        db: Database session
        dependent_id: ID of the dependent user
        guardian_user_id: ID of the guardian user
        relationship_id: ID of the guardian_dependent relationship
        is_primary: Whether this is the primary guardian
    
    Returns:
        EmergencyContact: The created/updated emergency contact
    """
    # Get guardian user details
    guardian = db.query(User).filter(User.id == guardian_user_id).first()
    if not guardian:
        raise ValueError(f"Guardian user {guardian_user_id} not found")
    
    # Check if auto-guardian contact already exists
    existing_contact = db.query(EmergencyContact).filter(
        EmergencyContact.user_id == dependent_id,
        EmergencyContact.guardian_relationship_id == relationship_id,
        EmergencyContact.source == "auto_guardian"
    ).first()
    
    if existing_contact:
        # Update existing contact
        existing_contact.contact_name = guardian.full_name or guardian.email.split('@')[0]
        existing_contact.phone_number = guardian.phone_number or "+0000000000"
        existing_contact.contact_email = guardian.email
        existing_contact.relationship = "Primary Guardian" if is_primary else "Collaborator Guardian"
        existing_contact.priority = 1 if is_primary else 2
        existing_contact.is_active = True
        existing_contact.updated_at = datetime.utcnow()
        
        db.commit()
        db.refresh(existing_contact)
        return existing_contact
    else:
        # Create new auto-guardian contact
        new_contact = EmergencyContact(
            user_id=dependent_id,
            contact_name=guardian.full_name or guardian.email.split('@')[0],
            phone_number=guardian.phone_number or "+0000000000",
            contact_email=guardian.email,
            relationship="Primary Guardian" if is_primary else "Collaborator Guardian",
            priority=1 if is_primary else 2,
            is_active=True,
            source="auto_guardian",
            guardian_relationship_id=relationship_id
        )
        
        db.add(new_contact)
        db.commit()
        db.refresh(new_contact)
        return new_contact


def remove_guardian_contact_for_dependent(
    db: Session,
    dependent_id: int,
    relationship_id: int
) -> bool:
    """
    Remove auto-guardian emergency contact when guardian relationship is revoked
    
    Args:
        db: Database session
        dependent_id: ID of the dependent user
        relationship_id: ID of the guardian_dependent relationship
    
    Returns:
        bool: True if contact was removed
    """
    contact = db.query(EmergencyContact).filter(
        EmergencyContact.user_id == dependent_id,
        EmergencyContact.guardian_relationship_id == relationship_id,
        EmergencyContact.source == "auto_guardian"
    ).first()
    
    if contact:
        db.delete(contact)
        db.commit()
        return True
    
    return False


def sync_all_guardian_contacts_for_dependent(
    db: Session,
    dependent_id: int
) -> List[EmergencyContact]:
    """
    Sync ALL guardians (primary + collaborators) as emergency contacts for a dependent
    
    This should be called:
    - When a new guardian relationship is created
    - When a guardian's profile is updated
    - Periodically to ensure sync
    
    Args:
        db: Database session
        dependent_id: ID of the dependent user
    
    Returns:
        List[EmergencyContact]: All auto-generated guardian emergency contacts
    """
    # Get all active guardian relationships for this dependent
    # ✅ FIXED: Removed status filter since GuardianDependent may not have status field
    relationships = db.query(GuardianDependent).filter(
        GuardianDependent.dependent_id == dependent_id
        # Removed: GuardianDependent.is_active == True  (if your model doesn't have this)
        # Removed: GuardianDependent.status == "active"  (if your model doesn't have this)
    ).all()
    
    created_contacts = []
    
    for relationship in relationships:
        try:
            contact = sync_guardian_contacts_for_dependent(
                db=db,
                dependent_id=dependent_id,
                guardian_user_id=relationship.guardian_id,
                relationship_id=relationship.id,
                is_primary=relationship.is_primary
            )
            created_contacts.append(contact)
        except Exception as e:
            print(f"❌ Error syncing guardian {relationship.guardian_id}: {e}")
            continue
    
    return created_contacts


# ================================================
# API ENDPOINTS
# ================================================

@router.post("/sync-guardian-contacts/{dependent_id}")
def sync_guardian_contacts_endpoint(
    dependent_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user_with_roles)
):
    """
    Manually trigger sync of all guardian contacts for a dependent
    
    This endpoint can be called by:
    - Primary guardian
    - System admin
    - Automated jobs
    """
    # Check if current user is primary guardian of this dependent
    relationship = db.query(GuardianDependent).filter(
        GuardianDependent.dependent_id == dependent_id,
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.is_primary == True
    ).first()
    
    # ✅ Check if user has is_admin attribute
    is_admin = getattr(current_user, 'is_admin', False)
    
    if not relationship and not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only primary guardian can sync emergency contacts"
        )
    
    try:
        contacts = sync_all_guardian_contacts_for_dependent(db, dependent_id)
        
        return {
            "success": True,
            "message": f"Synced {len(contacts)} guardian contacts",
            "contacts": [
                {
                    "id": c.id,
                    "name": c.contact_name,
                    "phone": c.phone_number,
                    "email": c.contact_email,
                    "relationship": c.relationship,
                    "priority": c.priority,
                    "source": c.source
                }
                for c in contacts
            ]
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to sync guardian contacts: {str(e)}"
        )


# ================================================
# BACKGROUND TASKS / HOOKS
# ================================================

# def on_guardian_relationship_created(
#     db: Session,
#     relationship: GuardianDependent
# ):
#     """
#     Hook: Called when a new guardian relationship is created
#     Automatically creates emergency contact for dependent
#     """
#     try:
#         contact = sync_guardian_contacts_for_dependent(
#             db=db,
#             dependent_id=relationship.dependent_id,
#             guardian_user_id=relationship.guardian_id,
#             relationship_id=relationship.id,
#             is_primary=relationship.is_primary
#         )
#         print(f"✅ Auto-created emergency contact {contact.id} for dependent {relationship.dependent_id}")
#     except Exception as e:
#         print(f"❌ Error creating auto emergency contact: {e}")
def on_guardian_relationship_created(db: Session, relationship: GuardianDependent):
    """
    Auto-create emergency contact when guardian-dependent relationship is created
    Works for BOTH primary and collaborator guardians
    """
    try:
        # Get guardian user info
        guardian = db.query(User).filter(User.id == relationship.guardian_id).first()
        
        if not guardian:
            print(f"⚠️ Guardian {relationship.guardian_id} not found")
            return
        
        # Check if emergency contact already exists
        existing_contact = db.query(EmergencyContact).filter(
            EmergencyContact.user_id == relationship.dependent_id,
            EmergencyContact.phone_number == guardian.phone_number
        ).first()
        
        if existing_contact:
            print(f"ℹ️ Emergency contact already exists for {guardian.full_name}")
            return
        
        # Create emergency contact for dependent
        new_contact = EmergencyContact(
            user_id=relationship.dependent_id,  # The dependent's user_id
            contact_name=guardian.full_name,
            phone_number=guardian.phone_number,
            relationship=f"{relationship.guardian_type.capitalize()} Guardian",  # "Primary Guardian" or "Collaborator Guardian"
            is_auto_generated=True,  # Flag to identify auto-generated contacts
            auto_from_guardian_id=relationship.guardian_id  # Track which guardian created this
        )
        
        db.add(new_contact)
        db.commit()
        
        print(f"✅ Auto-created emergency contact: {guardian.full_name} → Dependent {relationship.dependent_id}")
        
    except Exception as e:
        print(f"❌ Error auto-creating emergency contact: {e}")
        db.rollback()
        raise

def on_guardian_relationship_updated(
    db: Session,
    relationship: GuardianDependent
):
    """
    Hook: Called when guardian relationship is updated
    Updates the corresponding emergency contact
    """
    try:
        contact = sync_guardian_contacts_for_dependent(
            db=db,
            dependent_id=relationship.dependent_id,
            guardian_user_id=relationship.guardian_id,
            relationship_id=relationship.id,
            is_primary=relationship.is_primary
        )
        print(f"✅ Updated auto emergency contact {contact.id}")
    except Exception as e:
        print(f"❌ Error updating auto emergency contact: {e}")


def on_guardian_relationship_revoked(
    db: Session,
    relationship: GuardianDependent
):
    """
    Hook: Called when guardian relationship is revoked
    Removes the auto-generated emergency contact
    """
    try:
        removed = remove_guardian_contact_for_dependent(
            db=db,
            dependent_id=relationship.dependent_id,
            relationship_id=relationship.id
        )
        if removed:
            print(f"✅ Removed auto emergency contact for relationship {relationship.id}")
    except Exception as e:
        print(f"❌ Error removing auto emergency contact: {e}")


def on_guardian_profile_updated(
    db: Session,
    guardian_user_id: int
):
    """
    Hook: Called when a guardian updates their profile
    Updates all emergency contacts where they are listed as guardian
    """
    try:
        # Find all relationships where this user is a guardian
        relationships = db.query(GuardianDependent).filter(
            GuardianDependent.guardian_id == guardian_user_id
        ).all()
        
        updated_count = 0
        for relationship in relationships:
            contact = sync_guardian_contacts_for_dependent(
                db=db,
                dependent_id=relationship.dependent_id,
                guardian_user_id=guardian_user_id,
                relationship_id=relationship.id,
                is_primary=relationship.is_primary
            )
            updated_count += 1
        
        print(f"✅ Updated {updated_count} emergency contacts after guardian profile update")
    except Exception as e:
        print(f"❌ Error updating emergency contacts after profile update: {e}")