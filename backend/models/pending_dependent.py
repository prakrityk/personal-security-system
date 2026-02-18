from sqlalchemy import Integer, Column, ForeignKey, String, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from models.base import Base


class PendingDependent(Base):
    __tablename__ = "pending_dependent"

    id = Column(Integer, primary_key=True, index=True)
    guardian_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    dependent_name = Column(String(250), nullable=False)
    relation = Column(String(50), nullable=False)
    
    # ✅ FIX: Map Python 'age' attribute to database 'Age' column (capital A)
    # This tells SQLAlchemy: "In Python code use 'age', but in the database it's 'Age'"
    age = Column("Age", Integer, nullable=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships (add if they're in your actual file)
    qr_invitations = relationship("QRInvitation", back_populates="pending_dependent", cascade="all, delete-orphan")