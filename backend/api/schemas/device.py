"""
Pydantic schemas for device registration
"""

from typing import Literal, Optional

from pydantic import BaseModel, Field


class DeviceRegisterRequest(BaseModel):
    fcm_token: str = Field(..., min_length=10, max_length=512)
    platform: Literal["android", "ios", "web"] = Field("android")
    device_info: Optional[str] = Field(
        None, max_length=255, description="Optional device model / OS info"
    )


class DeviceRegisterResponse(BaseModel):
    success: bool = True
    message: str = "Device registered"

