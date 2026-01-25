"""
Refresh Token Model
Stores refresh tokens for token rotation
"""

from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime, timedelta
import secrets
from models.base import Base


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    token = Column(String(255), unique=True, nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Token metadata
    expires_at = Column(DateTime(timezone=True), nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)
    
    # Device/session tracking (optional)
    device_info = Column(String(255), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default="now()", nullable=False)
    last_used_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", backref="refresh_tokens")

    def __repr__(self):
        return f"<RefreshToken(id={self.id}, user_id={self.user_id}, expires_at={self.expires_at})>"

    @staticmethod
    def generate_token():
        """Generate a secure random refresh token"""
        return secrets.token_urlsafe(64)

    @staticmethod
    def calculate_expiry(days=30):
        """Calculate expiry datetime (default 30 days from now)"""
        return datetime.utcnow() + timedelta(days=days)

    def is_expired(self):
        """Check if refresh token has expired"""
        return datetime.utcnow() > self.expires_at

    def is_valid(self):
        """Check if refresh token is valid (not expired and not revoked)"""
        return not self.is_expired() and not self.is_revoked