"""
Device routes

Handles registration of FCM device tokens for push notifications.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from api.utils.auth_utils import get_current_user_with_roles
from api.schemas.device import DeviceRegisterRequest, DeviceRegisterResponse
from database.connection import get_db
from models.device import Device
from models.user import User


router = APIRouter()


@router.post("/devices/register", response_model=DeviceRegisterResponse)
async def register_device(
    payload: DeviceRegisterRequest,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db),
):
    """
    Register or update a device's FCM token for the current user.

    - If token already exists, it will be reassigned to this user and marked active.
    - If user already has this token, last_active_at is updated.
    """
    # If this fcm_token already exists, update its user + metadata
    device = (
        db.query(Device)
        .filter(Device.fcm_token == payload.fcm_token)
        .first()
    )

    if device:
        device.user_id = current_user.id
        device.platform = payload.platform
        device.device_info = payload.device_info
        device.is_active = True
    else:
        device = Device(
            user_id=current_user.id,
            fcm_token=payload.fcm_token,
            platform=payload.platform,
            device_info=payload.device_info,
            is_active=True,
        )
        db.add(device)

    db.commit()

    return DeviceRegisterResponse(
        success=True,
        message="Device registered successfully",
    )

