"""
Device model

Stores FCM push notification tokens per user and device.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.sql import func

from models.base import Base


class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)

    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # Raw FCM token from Firebase Messaging
    fcm_token = Column(String(512), nullable=False, unique=True, index=True)

    # 'android', 'ios', 'web', etc.
    platform = Column(String(32), nullable=False, default="android")

    # Simple flag to disable old devices without deleting
    is_active = Column(Boolean, nullable=False, default=True, index=True)

    # Optional device info (model name, OS version, etc.)
    device_info = Column(String(255), nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    last_active_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

