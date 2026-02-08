from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship  # Make sure this import is present
from models.base import Base


class Evidence(Base):
    __tablename__ = "evidence"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    evidence_type = Column(String(50), nullable=False)  # 'video' or 'audio'
    local_path = Column(String(500), nullable=False)
    file_url = Column(String(500), nullable=True)  # Google Drive URL after upload
    upload_status = Column(String(50), nullable=False, default='pending')  # 'pending', 'uploaded', 'failed'
    file_size = Column(Integer, nullable=True)  # File size in bytes
    duration = Column(Integer, nullable=True)  # Duration in seconds
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    uploaded_at = Column(DateTime(timezone=True), nullable=True)

    # ✅ ADD THIS RELATIONSHIP - THIS IS THE FIX
    user = relationship("User", back_populates="evidences")
    

    def __repr__(self):
        return f"<Evidence(id={self.id}, user_id={self.user_id}, type={self.evidence_type}, status={self.upload_status})>"

    def to_dict(self):
        """Convert model to dictionary for API responses"""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "evidence_type": self.evidence_type,
            "local_path": self.local_path,
            "file_url": self.file_url,
            "upload_status": self.upload_status,
            "file_size": self.file_size,
            "duration": self.duration,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "uploaded_at": self.uploaded_at.isoformat() if self.uploaded_at else None,
        }