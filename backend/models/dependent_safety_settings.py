"""
Dependent Safety Settings Model
Per-dependent safety toggles configured by the primary guardian.
One row per dependent; the dependent's device (and collaborator view) reads this.
"""

from sqlalchemy import Column, Integer, Boolean, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from models.base import Base


class DependentSafetySettings(Base):
    __tablename__ = "dependent_safety_settings"

    # One row per dependent (primary key = dependent_id)
    dependent_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
        nullable=False,
    )

    live_location = Column(Boolean, default=False, nullable=False)
    audio_recording = Column(Boolean, default=False, nullable=False)
    motion_detection = Column(Boolean, default=False, nullable=False)
    auto_recording = Column(Boolean, default=False, nullable=False)

    updated_at = Column(DateTime(timezone=True), server_default="now()", nullable=True)

    dependent = relationship("User", foreign_keys=[dependent_id], backref="safety_settings")

    def __repr__(self):
        return (
            f"<DependentSafetySettings(dependent_id={self.dependent_id}, "
            f"motion_detection={self.motion_detection})>"
        )
