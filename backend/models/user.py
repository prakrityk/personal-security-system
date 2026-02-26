from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from models.base import Base

class User(Base):
    __tablename__ = "users"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Firebase UID
    firebase_uid = Column(String(128), unique=True, nullable=False, index=True)
    
    # User info
    full_name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    phone_number = Column(String(20), unique=True, nullable=False, index=True)
    
    # Login password
    hashed_password = Column(String(255), nullable=False)
    
    # Profile
    profile_picture = Column(String(500), nullable=True)
    
    # Verification
    email_verified = Column(Boolean, default=True, nullable=False)
    phone_verified = Column(Boolean, default=True, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Biometric & voice
    biometric_enabled = Column(Boolean, default=False, nullable=False)
    is_voice_registered = Column(Boolean, default=False, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationships
    user_roles = relationship(
        "UserRole",
        back_populates="user",
        cascade="all, delete-orphan"
    )
    roles = relationship(
        "Role",
        secondary="user_roles",
        back_populates="users"
    )

    # LiveLocation: one-to-one (one row per user)
    location = relationship("LiveLocation", back_populates="user", uselist=False)

    def __repr__(self):
        return f"<User(id={self.id}, firebase_uid={self.firebase_uid}, email={self.email}, full_name={self.full_name})>"