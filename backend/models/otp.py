from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from models.base import Base

class OTP(Base):
    __tablename__ = "otps"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, nullable=False, index=True)
    code = Column(String, nullable=False)
    is_verified = Column(Boolean, default=False)
    attempts = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_sent_at = Column(DateTime(timezone=True), nullable=True)