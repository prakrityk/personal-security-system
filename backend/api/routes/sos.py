"""
SOS Event routes

This is the "event reporting" contract used by:
- manual SOS press
- motion detection escalation

The backend receives an EVENT and handles server-side work (notify/store/etc).
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from api.utils.auth_utils import get_current_user_with_roles
from api.schemas.sos import SOSEventCreate, SOSEventCreateResponse
from database.connection import get_db
from models.device import Device
from models.emergency_contact import EmergencyContact
from models.guardian_dependent import GuardianDependent
from models.sos_event import SOSEvent
from models.user import User
from services.notification_helper import NotificationHelper


router = APIRouter()


def _has_any_role(user: User, allowed: set[str]) -> bool:
    # get_current_user injects `role_names` list at runtime
    role_names = getattr(user, "role_names", []) or []
    return any(r in allowed for r in role_names)


@router.post("/sos/events", response_model=SOSEventCreateResponse)
async def create_sos_event(
    payload: SOSEventCreate,
    current_user: User = Depends(get_current_user_with_roles),
    db: Session = Depends(get_db),
):
    """
    Create an SOS event for the authenticated user.

    Notes:
    - user_id is NEVER accepted from the client (prevents spoofing)
    - basic role gate: dependent or global_user can create events
    """

    allowed_roles = {"child", "elderly", "global_user", "guardian", "admin"}
    if not _has_any_role(current_user, allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Your account is not allowed to create SOS events.",
        )

    lat = payload.location.lat if payload.location else None
    lng = payload.location.lng if payload.location else None

    event = SOSEvent(
        user_id=current_user.id,
        trigger_type=payload.trigger_type,
        event_type=payload.event_type,
        app_state=payload.app_state,
        latitude=lat,
        longitude=lng,
        event_timestamp=payload.timestamp,
    )

    db.add(event)
    db.commit()
    db.refresh(event)

    # --------------------------------------------------
    # Notify guardians + app-using emergency contacts
    # --------------------------------------------------

    # 1) Guardians for this dependent (primary + collaborators)
    guardian_rels = (
        db.query(GuardianDependent)
        .filter(GuardianDependent.dependent_id == current_user.id)
        .all()
    )
    guardian_user_ids = {rel.guardian_id for rel in guardian_rels}

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
    if contact_phones:
        contact_users = (
            db.query(User)
            .filter(User.phone_number.in_(contact_phones))
            .all()
        )
        contact_user_ids = {u.id for u in contact_users}
    else:
        contact_user_ids = set()

    recipient_user_ids = (guardian_user_ids | contact_user_ids) - {current_user.id}
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

        # For motion-triggered SOS, send a motion-specific alert.
        if payload.trigger_type == "motion":
            NotificationHelper.send_motion_detection_alert(
                tokens=list(tokens),
                dependent_name=current_user.full_name,
                event_id=event.id,
                detection_type=payload.event_type,
            )
        else:
            # Default manual SOS alert
            NotificationHelper.send_sos_alert(
                tokens=list(tokens),
                dependent_name=current_user.full_name,
                event_type=payload.event_type,
                event_id=event.id,
                location=(
                    {"lat": lat, "lng": lng}
                    if lat is not None and lng is not None
                    else None
                ),
            )

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
    if self_tokens:
        # Use a generic safety status update:
        # "SOS sent to your emergency contacts."
        NotificationHelper.send_safety_status_update(
            tokens=list(self_tokens),
            status_message="SOS sent to your emergency contacts.",
            event_id=event.id,
        )

    return SOSEventCreateResponse(
        event_id=event.id,
        message="SOS event recorded. Notifications queued.",
    )

