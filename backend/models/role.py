"""
Role model
Defines the 5 system roles with their permissions
"""

from sqlalchemy import Column, Integer, String, Text
from sqlalchemy.orm import relationship
from models.base import Base


class Role(Base):
    __tablename__ = "roles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    role_name = Column(String(50), unique=True, nullable=False)
    role_description = Column(Text)

    # 🔴 THIS WAS MISSING
    user_roles = relationship(
        "UserRole",
        back_populates="role",
        cascade="all, delete-orphan"
    )
    users = relationship(
        "User",
        secondary="user_roles",
        back_populates="roles"
    )

    def __repr__(self):
        return f"<Role {self.role_name}>"
