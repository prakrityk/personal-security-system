"""
Evidence model - Stores evidence collection records
Used for automatic video/audio recording when threats are detected
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from models.base import Base


class Evidence(Base):
    __tablename__ = "evidence"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Foreign key to user
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    
    # Evidence details
    evidence_type = Column(String(50), nullable=False)  # "video" or "audio"
    local_path = Column(String(500), nullable=False)  # Device file path
    file_url = Column(String(500), nullable=True)  # Google Drive file ID
    upload_status = Column(String(50), default="pending", nullable=False)  # pending, uploaded, failed
    
    # File metadata
    file_size = Column(Integer, nullable=True)  # bytes
    duration = Column(Integer, nullable=True)  # seconds
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    uploaded_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relationship to User
    user = relationship("User", back_populates="evidences")
    
    def __repr__(self):
        return f"<Evidence(id={self.id}, user_id={self.user_id}, type={self.evidence_type}, status={self.upload_status})>"