"""
User model - Firebase Authentication Ready (With Password)
Represents users table in database

Flow:
- Firebase verifies phone + email during registration
- User sets password during registration
- Daily login uses email + password (not Firebase)
- firebase_uid proves user was verified by Firebase
"""
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from models.base import Base


class User(Base):
    __tablename__ = "users"
    
    # Primary key
    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    
    # Firebase UID - Proof that user was verified by Firebase
    firebase_uid = Column(String(128), unique=True, nullable=False, index=True)
    
    # User information
    full_name = Column(String(255), nullable=False)
    email = Column(String(255), unique=True, nullable=False, index=True)
    phone_number = Column(String(20), unique=True, nullable=False, index=True)
    
    # Password for daily login (email + password)
    hashed_password = Column(String(255), nullable=False)
    
    # Profile
    profile_picture = Column(String(500), nullable=True)
    
    # Verification status (set by Firebase during registration)
    # Once Firebase verifies, these are TRUE and never change
    email_verified = Column(Boolean, default=True, nullable=False)
    phone_verified = Column(Boolean, default=True, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    
    # 🔐 Biometric Authentication (ADDED)
    # Guardian users must enable biometric authentication
    # Personal users can optionally enable it
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
    # evidences = relationship(
    #     "Evidence",
    #     back_populates="user",
    #     cascade="all, delete-orphan"
    # )

    def __repr__(self):
        return f"<User(id={self.id}, firebase_uid={self.firebase_uid}, email={self.email}, full_name={self.full_name}, biometric_enabled={self.biometric_enabled})>"