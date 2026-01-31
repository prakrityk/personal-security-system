"""
Emergency Contact Utilities
Helper functions for auto-syncing guardian emergency contacts
"""

from sqlalchemy.orm import Session
from models.guardian_dependent import GuardianDependent
from models.emergency_contact import EmergencyContact
from models.user import User


def sync_guardian_contacts_for_dependent(dependent_id: int, db: Session):
    """
    Auto-sync emergency contacts for a dependent based on their guardians
    
    This function:
    1. Gets all guardians (primary + collaborators) for the dependent
    2. Creates/updates emergency contacts for each guardian
    3. Deactivates contacts for removed guardians
    
    Should be called:
    - When a guardian approves a QR code (new relationship)
    - When a collaborator joins
    - When a guardian is removed
    """
    try:
        print(f"🔄 Syncing guardian contacts for dependent {dependent_id}")
        
        # Get all active guardian relationships
        relationships = db.query(GuardianDependent).filter(
            GuardianDependent.dependent_id == dependent_id
        ).all()
        
        active_guardian_ids = set()
        
        for rel in relationships:
            active_guardian_ids.add(rel.guardian_id)
            
            # Get guardian user info
            guardian = db.query(User).filter(User.id == rel.guardian_id).first()
            
            if not guardian:
                continue
            
            # Check if emergency contact already exists for this guardian
            existing_contact = db.query(EmergencyContact).filter(
                EmergencyContact.user_id == dependent_id,
                EmergencyContact.guardian_relationship_id == rel.id
            ).first()
            
            if existing_contact:
                # Update existing contact
                existing_contact.contact_name = guardian.full_name
                existing_contact.contact_phone = guardian.phone_number
                existing_contact.contact_email = guardian.email
                existing_contact.relationship = f"{rel.guardian_type.title()} Guardian"
                existing_contact.is_active = True
                
                # Set priority based on guardian type
                if rel.guardian_type == "primary":
                    existing_contact.priority = 1  # Highest priority
                else:
                    existing_contact.priority = 10  # Lower priority for collaborators
                
                print(f"  ✏️ Updated contact: {guardian.full_name}")
            else:
                # Create new emergency contact
                new_contact = EmergencyContact(
                    user_id=dependent_id,
                    contact_name=guardian.full_name,
                    contact_phone=guardian.phone_number,
                    contact_email=guardian.email,
                    relationship=f"{rel.guardian_type.title()} Guardian",
                    priority=1 if rel.guardian_type == "primary" else 10,
                    is_active=True,
                    source="auto_guardian",
                    guardian_relationship_id=rel.id
                )
                
                db.add(new_contact)
                print(f"  ✅ Added contact: {guardian.full_name}")
        
        # Deactivate contacts for removed guardians
        all_auto_contacts = db.query(EmergencyContact).filter(
            EmergencyContact.user_id == dependent_id,
            EmergencyContact.source == "auto_guardian"
        ).all()
        
        for contact in all_auto_contacts:
            if contact.guardian_relationship_id:
                rel = db.query(GuardianDependent).filter(
                    GuardianDependent.id == contact.guardian_relationship_id
                ).first()
                
                if not rel:  # Relationship was deleted
                    contact.is_active = False
                    print(f"  ⚠️ Deactivated contact: {contact.contact_name}")
        
        db.commit()
        print(f"✅ Guardian contacts synced successfully")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error syncing guardian contacts: {e}")
        raise


def create_initial_guardian_contact(
    dependent_id: int,
    guardian_id: int,
    relationship_id: int,
    guardian_type: str,
    db: Session
):
    """
    Create initial emergency contact when guardian-dependent relationship is created
    
    This is called immediately after:
    - Guardian approves QR code
    - Collaborator accepts invitation
    """
    try:
        print(f"📝 Creating initial guardian contact: Guardian {guardian_id} → Dependent {dependent_id}")
        
        # Get guardian info
        guardian = db.query(User).filter(User.id == guardian_id).first()
        
        if not guardian:
            print(f"❌ Guardian {guardian_id} not found")
            return
        
        # Check if contact already exists
        existing = db.query(EmergencyContact).filter(
            EmergencyContact.user_id == dependent_id,
            EmergencyContact.guardian_relationship_id == relationship_id
        ).first()
        
        if existing:
            print(f"ℹ️ Contact already exists, skipping")
            return
        
        # Create emergency contact
        new_contact = EmergencyContact(
            user_id=dependent_id,
            contact_name=guardian.full_name,
            contact_phone=guardian.phone_number,
            contact_email=guardian.email,
            relationship=f"{guardian_type.title()} Guardian",
            priority=1 if guardian_type == "primary" else 10,
            is_active=True,
            source="auto_guardian",
            guardian_relationship_id=relationship_id
        )
        
        db.add(new_contact)
        db.commit()
        
        print(f"✅ Initial guardian contact created")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error creating initial guardian contact: {e}")


def remove_guardian_contact(relationship_id: int, db: Session):
    """
    Deactivate emergency contact when guardian relationship is removed
    
    This is called when:
    - Primary guardian revokes collaborator access
    - Dependent removes a guardian
    """
    try:
        print(f"🗑️ Removing guardian contact for relationship {relationship_id}")
        
        # Find and deactivate the contact
        contact = db.query(EmergencyContact).filter(
            EmergencyContact.guardian_relationship_id == relationship_id,
            EmergencyContact.source == "auto_guardian"
        ).first()
        
        if contact:
            contact.is_active = False
            db.commit()
            print(f"✅ Guardian contact deactivated")
        else:
            print(f"ℹ️ No guardian contact found")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error removing guardian contact: {e}")