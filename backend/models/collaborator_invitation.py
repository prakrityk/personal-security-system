"""
Collaborator Invitation Model
Stores invitations for collaborator guardians to join
"""

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from models.base import Base


class CollaboratorInvitation(Base):
    __tablename__ = "collaborator_invitations"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Who created this invitation (primary guardian)
    primary_guardian_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Which dependent this is for
    dependent_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Invitation details
    invitation_code = Column(String(100), unique=True, nullable=False, index=True)
    
    # Status: pending, accepted, expired, cancelled
    status = Column(String(20), default="pending", nullable=False, index=True)
    
    # Who joined using this invitation (once accepted)
    collaborator_guardian_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default="now()", nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    accepted_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationships
    primary_guardian = relationship("User", foreign_keys=[primary_guardian_id], backref="created_invitations")
    dependent = relationship("User", foreign_keys=[dependent_id], backref="collaborator_invitations")
    collaborator_guardian = relationship("User", foreign_keys=[collaborator_guardian_id], backref="accepted_invitations")

    def __repr__(self):
        return f"<CollaboratorInvitation(id={self.id}, code={self.invitation_code}, status={self.status})>"
    
    def is_expired(self):
        """Check if invitation has expired"""
        from datetime import datetime, timezone
        return datetime.now(timezone.utc) > self.expires_at
    
    def is_valid(self):
        """Check if invitation is valid (pending and not expired)"""
        return self.status == "pending" and not self.is_expired()