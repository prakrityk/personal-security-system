from sqlalchemy import Column, BigInteger, Float, DateTime, func, ForeignKey
from sqlalchemy.orm import relationship
from models.base import Base

class LiveLocation(Base):
    __tablename__ = "live_locations"

    # Primary key: one row per user
    user_id = Column(BigInteger, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True, index=True)
    
    # Location data
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    
    # Optional
    accuracy = Column(Float, nullable=True)
    altitude = Column(Float, nullable=True)
    heading = Column(Float, nullable=True)
    speed = Column(Float, nullable=True)
    
    # Timestamp: updated automatically
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    
    # Relationship back to user
    user = relationship("User", back_populates="location")

    def __repr__(self):
        return f"<LiveLocation(user_id={self.user_id}, lat={self.latitude}, lng={self.longitude}, updated_at={self.updated_at})>"