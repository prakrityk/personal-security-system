"""
Emergency Contact Model
Stores emergency contact information for users
"""

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from models.base import Base


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Owner of this emergency contact
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Contact information
    contact_name = Column(String(100), nullable=False)
    contact_phone = Column(String(20), nullable=False)
    contact_email = Column(String(255), nullable=True)
    
    # Relationship to user (e.g., "Mother", "Father", "Friend", "Neighbor")
    contact_relationship = Column(String(50), nullable=True)  # ✅ CHANGED from 'relationship' to 'contact_relationship'
    
    # Priority (1 = highest priority, lower number = contacted first)
    priority = Column(Integer, default=999, nullable=False)
    
    # Is this contact active/enabled?
    is_active = Column(Boolean, default=True, nullable=False)
    
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
    
    # ✅ Relationships - NO CONFLICT now
    user = relationship("User", foreign_keys=[user_id], backref="emergency_contacts")
    guardian_relationship = relationship("GuardianDependent", foreign_keys=[guardian_relationship_id])

    def __repr__(self):
        return f"<EmergencyContact(id={self.id}, user_id={self.user_id}, name={self.contact_name}, priority={self.priority})>"
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "contact_name": self.contact_name,
            "contact_phone": self.contact_phone,
            "contact_email": self.contact_email,
            "relationship": self.contact_relationship,  # ✅ UPDATED
            "priority": self.priority,
            "is_active": self.is_active,
            "source": self.source,
            "guardian_relationship_id": self.guardian_relationship_id,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }