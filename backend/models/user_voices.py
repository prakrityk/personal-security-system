from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, LargeBinary
from sqlalchemy.sql import func
from models.base import Base

class UserVoice(Base):
    __tablename__ = "user_voices"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    sample_number = Column(Integer, nullable=False)
    file_path = Column(String(500), nullable=False)
    mfcc_data = Column(LargeBinary, nullable=False)  
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self):
        return f"<UserVoice(id={self.id}, user_id={self.user_id}, sample_number={self.sample_number})>"
