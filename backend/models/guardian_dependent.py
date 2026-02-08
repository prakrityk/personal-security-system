"""
Guardian-Dependent Relationship Model
Stores approved relationships between guardians and dependents
"""

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from models.base import Base


class GuardianDependent(Base):
    __tablename__ = "guardian_dependents"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Guardian user
    guardian_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Dependent user (child or elderly)
    dependent_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Relationship type: e.g., "parent", "sibling", "caregiver", "grandparent"
    relation = Column(String(50), nullable=False)
    
    # Is this the primary guardian?
    is_primary = Column(Boolean, default=False, nullable=False)
    
    # ✨ NEW: Guardian type - "primary" or "collaborator"
    guardian_type = Column(String(20), default="primary", nullable=False)
    
    # Reference to original pending dependent (optional, for tracking)
    pending_dependent_id = Column(Integer, ForeignKey("pending_dependent.id", ondelete="SET NULL"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default="now()", nullable=False)

    # Relationships
    guardian = relationship("User", foreign_keys=[guardian_id], backref="dependents")
    dependent = relationship("User", foreign_keys=[dependent_id], backref="guardians")
    pending_dependent = relationship("PendingDependent", backref="approved_relationships")

    def __repr__(self):
        return f"<GuardianDependent(id={self.id}, guardian_id={self.guardian_id}, dependent_id={self.dependent_id}, relation={self.relation}, type={self.guardian_type})>"