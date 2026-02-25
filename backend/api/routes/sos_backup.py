"""
SOS Event routes

This is the "event reporting" contract used by:
- manual SOS press
- motion detection escalation
- voice activation

The backend receives an EVENT with optional voice and handles server-side work.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from api.utils.auth_utils import get_current_user_with_roles
from api.schemas.sos import SOSEventCreate, SOSEventCreateResponse
from database.connection import get_db
from models.device import Device
from models.emergency_contact import EmergencyContact
from models.guardian_dependent import GuardianDependent
from models.sos_event import SOSEvent
from models.user import User
from services.notification_helper import NotificationHelper

import os
import uuid
from fastapi import File, UploadFile, Form


router = APIRouter()


def _has_any_role(user: User, allowed: set[str]) -> bool:
    # get_current_user injects `role_names` list at runtime
    role_names = getattr(user, "role_names", []) or []
    return any(r in allowed for r in role_names)


@router.post("/sos/with-voice", response_model=SOSEventCreateResponse)
async def create_sos_with_voice(
    trigger_type: str = Form(...),
    event_type: str = Form(...),
    app_state: Optional[str] = Form(None),
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None),
    timestamp: Optional[str] = Form(None),
    voice_message: UploadFile = File(None),
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db),
):
    """
    Unified endpoint for SOS events with optional voice message.
    - If voice_message provided: uploads to local/S3, stores URL with event
    - If no voice_message: creates SOS event without voice
    - Sends FCM with voice URL included (if available)
    """
    
    print(f"\n🔥🔥🔥 SOS TRIGGERED BY USER: {current_user.id} - {current_user.full_name}")
    print(f"📋 Trigger type: {trigger_type}, Event type: {event_type}")
    print(f"📍 Location: lat={latitude}, lng={longitude}")
    
    # Permission check
    allowed_roles = {"child", "elderly", "global_user", "guardian", "admin"}
    if not _has_any_role(current_user, allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account is not allowed to create SOS events.",
        )

    # Parse timestamp if provided
    event_timestamp = None
    if timestamp:
        try:
            event_timestamp = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        except:
            event_timestamp = datetime.utcnow()
    else:
        event_timestamp = datetime.utcnow()

    # Step 1: Handle voice upload FIRST (if present)
    voice_message_url = None
    if voice_message:
        try:
            # Generate unique filename
            filename = f"voice_{uuid.uuid4().hex[:16]}.aac"
            
            # For now, save locally (swap to S3 later)
            file_path = f"uploads/{filename}"
            os.makedirs("uploads", exist_ok=True)
            
            # Write file
            with open(file_path, "wb") as f:
                f.write(await voice_message.read())
            
            # Generate URL
            base_url = os.getenv("BASE_URL", "http://localhost:8000")
            voice_message_url = f"{base_url}/uploads/{filename}"
            
            print(f"✅ Voice message saved: {voice_message_url}")
            
        except Exception as e:
            print(f"❌ Voice upload failed: {e}")
            # Continue without voice - don't fail the whole SOS
            voice_message_url = None

    # Step 2: Create SOS event WITH voice URL already included
    event = SOSEvent(
        user_id=current_user.id,
        trigger_type=trigger_type,
        event_type=event_type,
        app_state=app_state,
        latitude=latitude,
        longitude=longitude,
        event_timestamp=event_timestamp,
        voice_message_url=voice_message_url,  # Now included!
    )

    db.add(event)
    db.commit()
    db.refresh(event)
    
    print(f"✅ SOS Event created with ID: {event.id}")

    # --------------------------------------------------
    # Notify guardians + app-using emergency contacts
    # --------------------------------------------------

    # 1) Guardians for this dependent (primary + collaborators)
    print(f"🔍 Looking for guardians of dependent ID: {current_user.id}")
    guardian_rels = (
        db.query(GuardianDependent)
        .filter(GuardianDependent.dependent_id == current_user.id)
        .all()
    )
    guardian_user_ids = {rel.guardian_id for rel in guardian_rels}
    print(f"👥 Found {len(guardian_user_ids)} guardians: {guardian_user_ids}")

    # 2) Manual emergency contacts whose phone_number matches a registered user
    contacts = (
        db.query(EmergencyContact)
        .filter(
            EmergencyContact.user_id == current_user.id,
            EmergencyContact.is_active == True,  # noqa: E712
        )
        .all()
    )
    contact_phones = {c.phone_number for c in contacts if c.phone_number}
    print(f"📞 Found {len(contact_phones)} emergency contact phones: {contact_phones}")
    
    contact_user_ids = set()
    if contact_phones:
        contact_users = (
            db.query(User)
            .filter(User.phone_number.in_(contact_phones))
            .all()
        )
        contact_user_ids = {u.id for u in contact_users}
        print(f"👥 Contact users found: {contact_user_ids}")

    recipient_user_ids = (guardian_user_ids | contact_user_ids) - {current_user.id}
    print(f"🎯 Final recipient user IDs: {recipient_user_ids}")
    
    if recipient_user_ids:
        devices = (
            db.query(Device)
            .filter(
                Device.user_id.in_(recipient_user_ids),
                Device.is_active == True,  # noqa: E712
            )
            .all()
        )
        tokens = {d.fcm_token for d in devices if d.fcm_token}
        print(f"🔥 FOUND {len(tokens)} GUARDIAN FCM TOKENS: {tokens}")
        
        if not tokens:
            print("⚠️ No FCM tokens found for recipients!")

        # Send notification WITH voice URL included
        if trigger_type == "motion":
            print("📨 Sending motion detection alert...")
            NotificationHelper.send_motion_detection_alert(
                tokens=list(tokens),
                dependent_name=current_user.full_name,
                event_id=event.id,
                detection_type=event_type,
                voice_message_url=voice_message_url,
            )
        else:
            print("📨 Sending SOS alert...")
            NotificationHelper.send_sos_alert(
                tokens=list(tokens),
                dependent_name=current_user.full_name,
                event_type=event_type,
                event_id=event.id,
                location=(
                    {"lat": latitude, "lng": longitude}
                    if latitude is not None and longitude is not None
                    else None
                ),
                voice_message_url=voice_message_url,
            )
    else:
        print("⚠️ No recipient user IDs found!")

    # --------------------------------------------------
    # Self-notification: user who triggered SOS
    # --------------------------------------------------
    self_devices = (
        db.query(Device)
        .filter(
            Device.user_id == current_user.id,
            Device.is_active == True,  # noqa: E712
        )
        .all()
    )
    self_tokens = {d.fcm_token for d in self_devices if d.fcm_token}
    print(f"📱 Self tokens found: {len(self_tokens)}")
    
    if self_tokens:
        NotificationHelper.send_safety_status_update(
            tokens=list(self_tokens),
            status_message="SOS sent to your emergency contacts.",
            event_id=event.id,
        )

    return SOSEventCreateResponse(
        event_id=event.id,
        message="SOS event recorded. Notifications queued.",
        voice_message_url=voice_message_url,
    )

@router.get("/sos/events/{event_id}")
async def get_sos_event(
    event_id: int,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db),
):
    """
    Get SOS event details by ID.
    Used by guardians to view SOS alert details.
    """
    print(f"🔍 Fetching SOS event details for ID: {event_id}")
    
    # Get the SOS event
    event = db.query(SOSEvent).filter(SOSEvent.id == event_id).first()
    
    if not event:
        print(f"❌ SOS event {event_id} not found")
        raise HTTPException(status_code=404, detail="SOS event not found")
    
    # Get the dependent (user who triggered SOS)
    dependent = db.query(User).filter(User.id == event.user_id).first()
    dependent_name = dependent.full_name if dependent else "Unknown"
    
    # Build response
    response = {
        "id": event.id,
        "user_id": event.user_id,
        "dependent_name": dependent_name,
        "trigger_type": event.trigger_type,
        "event_type": event.event_type,
        "app_state": event.app_state,
        "latitude": event.latitude,
        "longitude": event.longitude,
        "voice_message_url": event.voice_message_url,
        "created_at": event.created_at.isoformat() if event.created_at else None,
        "event_timestamp": event.event_timestamp.isoformat() if event.event_timestamp else None,
    }
    
    print(f"✅ SOS event details retrieved: {response}")
    return response