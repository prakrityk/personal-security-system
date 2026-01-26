from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from models.base import Base

class PendingUser(Base):
    __tablename__ = "pending_users"

    id = Column(Integer, primary_key=True, index=True)

    full_name = Column(String(255), nullable=False)
    email = Column(String(255), index=True, nullable=False)
    phone_number = Column(String(20), nullable=False)
    hashed_password = Column(String(255), nullable=False)

    email_otp = Column(String(6), nullable=False)
    otp_attempts = Column(Integer, default=0)
    is_email_verified = Column(Boolean, default=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
