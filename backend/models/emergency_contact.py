"""
Emergency Contact Model - CORRECTED VERSION
Stores emergency contact information for users
Includes auto-generation tracking for guardian contacts
"""

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship as sa_relationship  # ✅ RENAMED to avoid conflict
from models.base import Base


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Owner of this emergency contact (the dependent)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Contact information
    contact_name = Column(String(100), nullable=False)
    
    # ✅ Using 'phone_number' (was 'phone_number')
    phone_number = Column(String(20), nullable=False)
    
    contact_email = Column(String(255), nullable=True)
    
    # ✅ Using 'relationship' as column name (this caused the conflict)
    # IMPORTANT: We use 'relationship' as the column name but 'sa_relationship' for the ORM function
    relationship = Column(String(50), nullable=True)  # e.g., "Primary Guardian", "Collaborator Guardian"
    
    # Priority (1 = highest priority, lower number = contacted first)
    priority = Column(Integer, default=999, nullable=False)
    
    # Is this contact active/enabled?
    is_active = Column(Boolean, default=True, nullable=False)
    
    # ✅ NEW: Track if this contact was auto-generated from guardian relationship
    is_auto_generated = Column(Boolean, default=False, nullable=False, index=True)
    
    # ✅ NEW: If auto-generated, which guardian created this contact?
    auto_from_guardian_id = Column(
        Integer, 
        ForeignKey("users.id", ondelete="CASCADE"), 
        nullable=True,
        index=True
    )
    
    # Source of contact (manual, phone_contacts, auto_guardian)
    # - manual: Added manually by user
    # - phone_contacts: Imported from phone
    # - auto_guardian: Auto-added from guardian relationship
    source = Column(String(20), default="manual", nullable=False)
    
    # If auto-added from guardian, store the relationship ID
    guardian_relationship_id = Column(
        Integer, 
        ForeignKey("guardian_dependents.id", ondelete="CASCADE"), 
        nullable=True
    )
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default="now()", nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default="now()", onupdate="now()", nullable=False)
    
    # ✅ FIXED: Use sa_relationship (the imported function) instead of relationship (the column)
    user = sa_relationship("User", foreign_keys=[user_id], backref="emergency_contacts")
    auto_from_guardian = sa_relationship("User", foreign_keys=[auto_from_guardian_id])
    guardian_rel = sa_relationship("GuardianDependent", foreign_keys=[guardian_relationship_id])

    def __repr__(self):
        auto = " [AUTO]" if self.is_auto_generated else ""
        return f"<EmergencyContact(id={self.id}, user_id={self.user_id}, name={self.contact_name}{auto})>"
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "contact_name": self.contact_name,
            "phone_number": self.phone_number,
            "contact_email": self.contact_email,
            "relationship": self.relationship,  # This is the column value, not the function
            "priority": self.priority,
            "is_active": self.is_active,
            "is_auto_generated": self.is_auto_generated,
            "auto_from_guardian_id": self.auto_from_guardian_id,
            "source": self.source,
            "guardian_relationship_id": self.guardian_relationship_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }