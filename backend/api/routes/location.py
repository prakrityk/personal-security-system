from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from typing import Optional
from pydantic import BaseModel

from database.connection import get_db
from models.user import User
from models.live_location import LiveLocation
from api.utils.auth_utils import get_current_user

router = APIRouter()

# Pydantic model for request
class LocationRequest(BaseModel):
    latitude: float
    longitude: float
    accuracy: Optional[float] = None
    altitude: Optional[float] = None
    heading: Optional[float] = None
    speed: Optional[float] = None

# Save or update location
@router.post("/location", response_model=dict)
def save_my_location(
    data: LocationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not current_user:
        raise HTTPException(status_code=401, detail="Invalid authentication")

    user_id = current_user.id

    # UPSERT: update if exists, else insert
    loc = db.query(LiveLocation).filter(LiveLocation.user_id == user_id).first()
    if loc:
        loc.latitude = data.latitude
        loc.longitude = data.longitude
        loc.accuracy = data.accuracy
        loc.altitude = data.altitude
        loc.heading = data.heading
        loc.speed = data.speed
        db.commit()
        db.refresh(loc)
        action = "updated"
    else:
        loc = LiveLocation(
            user_id=user_id,
            latitude=data.latitude,
            longitude=data.longitude,
            accuracy=data.accuracy,
            altitude=data.altitude,
            heading=data.heading,
            speed=data.speed
        )
        db.add(loc)
        db.commit()
        db.refresh(loc)
        action = "created"

    return {
        "message": "Location stored successfully",
        "user_id": user_id,
        "latitude": loc.latitude,
        "longitude": loc.longitude,
        "updated_at": loc.updated_at.isoformat(),
        "action": action
    }