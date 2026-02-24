"""
Pydantic schemas for SOS events
"""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field


class LocationPayload(BaseModel):
    lat: float
    lng: float


class SOSEventCreate(BaseModel):
    trigger_type: Literal["manual", "motion"] = Field(..., description="What triggered the SOS")
    event_type: str = Field(..., min_length=1, max_length=64, description="Specific type of event")

    # Optional client context
    timestamp: Optional[datetime] = Field(None, description="Client timestamp (UTC preferred)")
    location: Optional[LocationPayload] = None
    app_state: Optional[Literal["foreground", "background"]] = None


class SOSEventCreateResponse(BaseModel):
    status: Literal["success"] = "success"
    event_id: int
    message: str
    voice_message_url: Optional[str] = Field(None, description="URL of the voice message if uploaded")