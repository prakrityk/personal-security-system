"""
Emergency Contact Routes - FIXED FOR COLLABORATOR VIEW ACCESS
Handles emergency contact operations for guardians and personal users
"""

from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

# Schemas
from api.schemas.emergency_contact import (
    EmergencyContactCreate,
    EmergencyContactUpdate,
    EmergencyContactResponse,
    EmergencyContactBulkCreate,
    EmergencyContactBulkResponse,
    DependentEmergencyContactCreate,
    DependentEmergencyContactUpdate,
)

# Models
from models.user import User
from models.emergency_contact import EmergencyContact
from models.guardian_dependent import GuardianDependent
from models.role import Role
from models.user_roles import UserRole

# Dependencies
from api.utils.auth_utils import get_current_user_with_roles
from database.connection import get_db

router = APIRouter()


# ================================================
# HELPER FUNCTIONS
# ================================================

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
    """
    ⭐ NEW: Verify that current user is ANY guardian (primary or collaborator) for dependent
    This allows BOTH primary and collaborator guardians to VIEW contacts
    """
    relationship = db.query(GuardianDependent).filter(
        GuardianDependent.guardian_id == current_user.id,
        GuardianDependent.dependent_id == dependent_id
    ).first()
    
    if not relationship:
        raise HTTPException(
            status_code=403,
            detail="You are not a guardian for this dependent"
        )
    
    return relationship


# ================================================
# PERSONAL EMERGENCY CONTACTS
# ================================================

@router.post("/my-emergency-contacts", response_model=EmergencyContactResponse)
async def create_my_emergency_contact(
    contact_data: EmergencyContactCreate,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Create an emergency contact for current user"""
    try:
        print(f"📝 Creating emergency contact for user {current_user.id}")
        
        new_contact = EmergencyContact(
            user_id=current_user.id,
            contact_name=contact_data.contact_name,
            phone_number=contact_data.phone_number,
            contact_email=contact_data.contact_email,
            relationship=contact_data.relationship,
            priority=contact_data.priority,
            source="manual",
            is_active=True
        )
        
        db.add(new_contact)
        db.commit()
        db.refresh(new_contact)
        
        print(f"✅ Emergency contact created: {new_contact.contact_name}")
        
        return EmergencyContactResponse(
            id=new_contact.id,
            user_id=new_contact.user_id,
            contact_name=new_contact.contact_name,
            phone_number=new_contact.phone_number,
            contact_email=new_contact.contact_email,
            relationship=new_contact.relationship,
            priority=new_contact.priority,
            is_active=new_contact.is_active,
            source=new_contact.source,
            guardian_relationship_id=new_contact.guardian_relationship_id,
            created_at=new_contact.created_at,
            updated_at=new_contact.updated_at
        )
    
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating emergency contact: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create emergency contact: {str(e)}"
        )


@router.get("/my-emergency-contacts", response_model=List[EmergencyContactResponse])
async def get_my_emergency_contacts(
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Get all emergency contacts for current user"""
    try:
        print(f"📥 Fetching emergency contacts for user {current_user.id}")
        
        contacts = db.query(EmergencyContact).filter(
            EmergencyContact.user_id == current_user.id
        ).order_by(EmergencyContact.priority, desc(EmergencyContact.created_at)).all()
        
        result = [
            EmergencyContactResponse(
                id=contact.id,
                user_id=contact.user_id,
                contact_name=contact.contact_name,
                phone_number=contact.phone_number,
                contact_email=contact.contact_email,
                relationship=contact.relationship,
                priority=contact.priority,
                is_active=contact.is_active,
                source=contact.source,
                guardian_relationship_id=contact.guardian_relationship_id,
                created_at=contact.created_at,
                updated_at=contact.updated_at
            )
            for contact in contacts
        ]
        
        print(f"✅ Found {len(result)} emergency contacts")
        return result
    
    except Exception as e:
        print(f"❌ Error fetching emergency contacts: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch emergency contacts: {str(e)}"
        )


@router.put("/my-emergency-contacts/{contact_id}", response_model=EmergencyContactResponse)
async def update_my_emergency_contact(
    contact_id: int,
    contact_data: EmergencyContactUpdate,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Update an emergency contact - PROTECTED from auto_guardian modification"""
    try:
        print(f"✏️ Updating emergency contact {contact_id}")
        
        contact = db.query(EmergencyContact).filter(
            EmergencyContact.id == contact_id,
            EmergencyContact.user_id == current_user.id
        ).first()
        
        if not contact:
            raise HTTPException(
                status_code=404,
                detail="Emergency contact not found"
            )
        
        # ✅ PROTECT: Cannot modify auto-guardian contacts
        if contact.source == "auto_guardian":
            raise HTTPException(
                status_code=403,
                detail="Cannot modify auto-generated guardian contacts. These are managed automatically based on your guardian relationships."
            )
        
        # Update fields
        if contact_data.contact_name is not None:
            contact.contact_name = contact_data.contact_name
        if contact_data.phone_number is not None:
            contact.phone_number = contact_data.phone_number
        if contact_data.contact_email is not None:
            contact.contact_email = contact_data.contact_email
        if contact_data.relationship is not None:
            contact.relationship = contact_data.relationship
        if contact_data.priority is not None:
            contact.priority = contact_data.priority
        if contact_data.is_active is not None:
            contact.is_active = contact_data.is_active
        
        contact.updated_at = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(contact)
        
        print(f"✅ Emergency contact updated")
        
        return EmergencyContactResponse(
            id=contact.id,
            user_id=contact.user_id,
            contact_name=contact.contact_name,
            phone_number=contact.phone_number,
            contact_email=contact.contact_email,
            relationship=contact.relationship,
            priority=contact.priority,
            is_active=contact.is_active,
            source=contact.source,
            guardian_relationship_id=contact.guardian_relationship_id,
            created_at=contact.created_at,
            updated_at=contact.updated_at
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error updating emergency contact: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update emergency contact: {str(e)}"
        )


@router.delete("/my-emergency-contacts/{contact_id}")
async def delete_my_emergency_contact(
    contact_id: int,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Delete an emergency contact - PROTECTED from auto_guardian deletion"""
    try:
        print(f"🗑️ Deleting emergency contact {contact_id}")
        
        contact = db.query(EmergencyContact).filter(
            EmergencyContact.id == contact_id,
            EmergencyContact.user_id == current_user.id
        ).first()
        
        if not contact:
            raise HTTPException(
                status_code=404,
                detail="Emergency contact not found"
            )
        
        # ✅ PROTECT: Cannot delete auto-guardian contacts
        if contact.source == "auto_guardian":
            raise HTTPException(
                status_code=403,
                detail="Cannot delete auto-generated guardian contacts. These are removed automatically when guardian access is revoked."
            )
        
        db.delete(contact)
        db.commit()
        
        print(f"✅ Emergency contact deleted")
        
        return {
            "success": True,
            "message": "Emergency contact deleted successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting emergency contact: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete emergency contact: {str(e)}"
        )


@router.post("/my-emergency-contacts/bulk", response_model=EmergencyContactBulkResponse)
async def bulk_import_emergency_contacts(
    bulk_data: EmergencyContactBulkCreate,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Bulk import emergency contacts from phone"""
    try:
        print(f"📥 Bulk importing {len(bulk_data.contacts)} contacts for user {current_user.id}")
        
        imported_count = 0
        skipped_count = 0
        errors = []
        
        for contact_data in bulk_data.contacts:
            try:
                # Check for duplicates by phone number
                existing = db.query(EmergencyContact).filter(
                    EmergencyContact.user_id == current_user.id,
                    EmergencyContact.phone_number == contact_data.phone_number
                ).first()
                
                if existing:
                    skipped_count += 1
                    print(f"⏭️ Skipping duplicate: {contact_data.contact_name}")
                    continue
                
                new_contact = EmergencyContact(
                    user_id=current_user.id,
                    contact_name=contact_data.contact_name,
                    phone_number=contact_data.phone_number,
                    contact_email=contact_data.contact_email,
                    relationship=contact_data.relationship,
                    priority=contact_data.priority or 3,
                    source="phone",
                    is_active=True
                )
                
                db.add(new_contact)
                imported_count += 1
                
            except Exception as e:
                errors.append(f"{contact_data.contact_name}: {str(e)}")
                print(f"❌ Error importing {contact_data.contact_name}: {e}")
        
        db.commit()
        
        print(f"✅ Bulk import completed: {imported_count} imported, {skipped_count} skipped")
        
        return EmergencyContactBulkResponse(
            success=True,
            imported=imported_count,
            skipped=skipped_count,
            errors=errors,
            message=f"Successfully imported {imported_count} contacts"
        )
    
    except Exception as e:
        db.rollback()
        print(f"❌ Error during bulk import: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to import contacts: {str(e)}"
        )


# ================================================
# DEPENDENT EMERGENCY CONTACTS - VIEW ACCESS
# ⭐ THIS IS THE CRITICAL FIX
# ================================================

@router.get("/guardian/dependent/{dependent_id}/emergency-contacts", 
            response_model=List[EmergencyContactResponse])
async def get_dependent_emergency_contacts_for_viewing(
    dependent_id: int,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """
    ⭐ FIXED: Get dependent's emergency contacts for viewing
    
    ✅ WORKS FOR BOTH: Primary Guardian AND Collaborator Guardian
    This endpoint allows READ access for ANY guardian (primary or collaborator)
    """
    try:
        print(f"📥 [VIEW MODE] Fetching contacts for dependent {dependent_id}")
        print(f"👤 Requested by user {current_user.id}")
        
        # ⭐ KEY FIX: Use verify_any_guardian instead of verify_primary_guardian
        # This allows both primary and collaborator guardians to VIEW
        verify_any_guardian(current_user, dependent_id, db)
        
        contacts = db.query(EmergencyContact).filter(
            EmergencyContact.user_id == dependent_id
        ).order_by(EmergencyContact.priority, desc(EmergencyContact.created_at)).all()
        
        result = [
            EmergencyContactResponse(
                id=contact.id,
                user_id=contact.user_id,
                contact_name=contact.contact_name,
                phone_number=contact.phone_number,
                contact_email=contact.contact_email,
                relationship=contact.relationship,
                priority=contact.priority,
                is_active=contact.is_active,
                source=contact.source,
                guardian_relationship_id=contact.guardian_relationship_id,
                created_at=contact.created_at,
                updated_at=contact.updated_at
            )
            for contact in contacts
        ]
        
        print(f"✅ Found {len(result)} emergency contacts (view mode)")
        print(f"👁️ Access granted to {'primary' if any(r.is_primary for r in [verify_any_guardian(current_user, dependent_id, db)]) else 'collaborator'} guardian")
        
        return result
    
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error fetching dependent emergency contacts: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to fetch emergency contacts: {str(e)}"
        )


# ================================================
# DEPENDENT EMERGENCY CONTACTS - EDIT ACCESS
# (Primary Guardian ONLY)
# ================================================

@router.post("/dependent/emergency-contacts", response_model=EmergencyContactResponse)
async def create_dependent_emergency_contact(
    contact_data: DependentEmergencyContactCreate,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Add an emergency contact for a dependent (Primary guardian only)"""
    try:
        print(f"📝 Adding emergency contact for dependent {contact_data.dependent_id}")
        
        # ⚠️ Only primary guardian can CREATE
        verify_primary_guardian(current_user, contact_data.dependent_id, db)
        
        new_contact = EmergencyContact(
            user_id=contact_data.dependent_id,
            contact_name=contact_data.contact_name,
            phone_number=contact_data.phone_number,
            contact_email=contact_data.contact_email,
            relationship=contact_data.relationship,
            priority=contact_data.priority,
            source="manual",
            is_active=True
        )
        
        db.add(new_contact)
        db.commit()
        db.refresh(new_contact)
        
        print(f"✅ Emergency contact added for dependent")
        
        return EmergencyContactResponse(
            id=new_contact.id,
            user_id=new_contact.user_id,
            contact_name=new_contact.contact_name,
            phone_number=new_contact.phone_number,
            contact_email=new_contact.contact_email,
            relationship=new_contact.relationship,
            priority=new_contact.priority,
            is_active=new_contact.is_active,
            source=new_contact.source,
            guardian_relationship_id=new_contact.guardian_relationship_id,
            created_at=new_contact.created_at,
            updated_at=new_contact.updated_at
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating dependent emergency contact: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to create emergency contact: {str(e)}"
        )


@router.put("/dependent/emergency-contacts/{contact_id}", 
            response_model=EmergencyContactResponse)
async def update_dependent_emergency_contact(
    contact_id: int,
    contact_data: DependentEmergencyContactUpdate,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Update a dependent's emergency contact (Primary guardian only)"""
    try:
        print(f"✏️ Updating dependent emergency contact {contact_id}")
        
        contact = db.query(EmergencyContact).filter(
            EmergencyContact.id == contact_id
        ).first()
        
        if not contact:
            raise HTTPException(
                status_code=404,
                detail="Emergency contact not found"
            )
        
        # ⚠️ Only primary guardian can UPDATE
        verify_primary_guardian(current_user, contact.user_id, db)
        
        # Update fields
        if contact_data.contact_name is not None:
            contact.contact_name = contact_data.contact_name
        if contact_data.phone_number is not None:
            contact.phone_number = contact_data.phone_number
        if contact_data.contact_email is not None:
            contact.contact_email = contact_data.contact_email
        if contact_data.relationship is not None:
            contact.relationship = contact_data.relationship
        if contact_data.priority is not None:
            contact.priority = contact_data.priority
        if contact_data.is_active is not None:
            contact.is_active = contact_data.is_active
        
        contact.updated_at = datetime.now(timezone.utc)
        
        db.commit()
        db.refresh(contact)
        
        print(f"✅ Dependent emergency contact updated")
        
        return EmergencyContactResponse(
            id=contact.id,
            user_id=contact.user_id,
            contact_name=contact.contact_name,
            phone_number=contact.phone_number,
            contact_email=contact.contact_email,
            relationship=contact.relationship,
            priority=contact.priority,
            is_active=contact.is_active,
            source=contact.source,
            guardian_relationship_id=contact.guardian_relationship_id,
            created_at=contact.created_at,
            updated_at=contact.updated_at
        )
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error updating dependent emergency contact: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to update emergency contact: {str(e)}"
        )


@router.delete("/dependent/emergency-contacts/{contact_id}")
async def delete_dependent_emergency_contact(
    contact_id: int,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db)
):
    """Delete a dependent's emergency contact (Primary guardian only) - PROTECTED"""
    try:
        print(f"🗑️ Deleting dependent emergency contact {contact_id}")
        
        contact = db.query(EmergencyContact).filter(
            EmergencyContact.id == contact_id
        ).first()
        
        if not contact:
            raise HTTPException(
                status_code=404,
                detail="Emergency contact not found"
            )
        
        # ⚠️ Only primary guardian can DELETE
        verify_primary_guardian(current_user, contact.user_id, db)
        
        # ✅ PROTECT: Even guardians shouldn't delete auto_guardian contacts manually
        if contact.source == "auto_guardian":
            raise HTTPException(
                status_code=400,
                detail="Cannot delete auto-generated guardian contacts. These are managed automatically when you revoke guardian access."
            )
        
        db.delete(contact)
        db.commit()
        
        print(f"✅ Dependent emergency contact deleted")
        
        return {
            "success": True,
            "message": "Emergency contact deleted successfully"
        }
    
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        print(f"❌ Error deleting dependent emergency contact: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to delete emergency contact: {str(e)}"
        )