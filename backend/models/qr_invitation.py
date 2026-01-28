"""
QR Invitation Model
Stores QR tokens for linking guardians and dependents
"""

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta, timezone
import uuid
from models.base import Base


class QRInvitation(Base):
    __tablename__ = "qr_invitations"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    qr_token = Column(String(255), unique=True, nullable=False, index=True)
    
    # Guardian who created the QR
    guardian_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Pending dependent reference
    pending_dependent_id = Column(Integer, ForeignKey("pending_dependent.id", ondelete="CASCADE"), nullable=False)
    
    # Child/Elderly who scanned (NULL until scanned)
    scanned_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    
    # Status: 'pending', 'scanned', 'approved', 'expired', 'rejected'
    status = Column(String(20), default="pending", nullable=False)
    
    # Approval flag
    is_approved = Column(Boolean, default=False, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default="now()", nullable=False)
    scanned_at = Column(DateTime(timezone=True), nullable=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    approved_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    guardian = relationship("User", foreign_keys=[guardian_id], backref="created_qr_invitations")
    scanned_by = relationship("User", foreign_keys=[scanned_by_user_id], backref="scanned_qr_invitations")
    pending_dependent = relationship("PendingDependent", back_populates="qr_invitations")

    def __repr__(self):
        return f"<QRInvitation(id={self.id}, token={self.qr_token[:8]}..., status={self.status})>"

    @staticmethod
    def generate_token():
        """Generate a unique UUID token for QR code"""
        return str(uuid.uuid4())

    @staticmethod
    def calculate_expiry(days=3):
        """Calculate expiry datetime (default 3 days from now)"""
        return datetime.now(timezone.utc) + timedelta(days=days)

    def is_expired(self):
        """Check if QR code has expired"""
        return datetime.now(timezone.utc) > self.expires_at

    def can_be_scanned(self):
        """Check if QR code can still be scanned"""
        return self.status == "pending" and not self.is_expired()