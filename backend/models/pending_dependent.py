from sqlalchemy import  Integer,Column,ForeignKey, String, DateTime
from sqlalchemy.sql import func
from models.base import Base

class pendingDependent(Base):
    __tablename__="pending_dependent"

    id=Column(Integer, primary_key=True, index=True)
    guardian_id=Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    dependent_name = Column(String(250), nullable=False)
    relation = Column(String(50), nullable=False)
    Age=Column(Integer, nullable=False )
    created_at = Column(DateTime(timezone=True), server_default=func.now())