"""
SOS Event model

This stores emergency events triggered by:
- manual SOS press
- motion detection escalation

The backend does NOT care how detection works; it only records events.
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.sql import func

from models.base import Base


class SOSEvent(Base):
    __tablename__ = "sos_events"

    id = Column(Integer, primary_key=True, index=True)

    # Who triggered the SOS (always derived from JWT in the API)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)

    # "manual" | "motion" (keep as string for flexibility)
    trigger_type = Column(String(32), nullable=False)

    # Example: "possible_fall", "abnormal_motion", "panic_button"
    event_type = Column(String(64), nullable=False)

    # "foreground" | "background" (debugging/analytics)
    app_state = Column(String(32), nullable=True)

    # Optional last-known location
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)

    # Client timestamp (optional); server will use created_at if not provided.
    event_timestamp = Column(DateTime(timezone=True), nullable=True)

    # Server timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

