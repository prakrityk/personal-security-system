"""
Backend helper for sending notifications with proper channel routing
Place this in: backend/services/notification_helper.py
"""

from typing import List, Optional, Dict, Any
from services.firebase_service import get_firebase_service


class NotificationChannelType:
    """Notification channel types matching Flutter implementation"""
    SOS_EVENT = "SOS_EVENT"                    # Channel: sos_alerts
    PANIC_MODE = "PANIC_MODE"                  # Channel: sos_alerts
    MOTION_DETECTION = "MOTION_DETECTION"      # Channel: sos_alerts
    
    SOS_ACKNOWLEDGED = "SOS_ACKNOWLEDGED"      # Channel: security_updates
    COUNTDOWN_WARNING = "COUNTDOWN_WARNING"    # Channel: security_updates
    SAFETY_STATUS = "SAFETY_STATUS"            # Channel: security_updates
    
    TRACKING_ACTIVE = "TRACKING_ACTIVE"        # Channel: location_tracking
    EVIDENCE_COLLECTION = "EVIDENCE_COLLECTION" # Channel: location_tracking
    
    PERMISSION_REQUIRED = "PERMISSION_REQUIRED" # Channel: app_system
    BATTERY_WARNING = "BATTERY_WARNING"         # Channel: app_system
    SERVICE_DISABLED = "SERVICE_DISABLED"       # Channel: app_system


class NotificationHelper:
    """
    Helper class for sending notifications through Firebase Cloud Messaging
    with proper channel routing and priority
    """

    @staticmethod
    def send_sos_alert(
        tokens: List[str],
        dependent_name: str,
        event_type: str,
        event_id: int,
        location: Optional[Dict[str, float]] = None,
        voice_message_url: Optional[str] = None
    ) -> None:
        """
        Send SOS emergency alert (highest priority)
        Routes to: sos_alerts channel
        """
        print(f"\n🔥🔥🔥 NOTIFICATION HELPER: send_sos_alert CALLED")
        print(f"📋 Tokens count: {len(tokens)}")
        print(f"📋 First few tokens: {[t[:20] + '...' for t in tokens[:3]]}")
        print(f"📋 Dependent: {dependent_name}, Event ID: {event_id}")
        print(f"📋 Voice URL: {voice_message_url}")
        
        title = "🚨 SOS Alert"
        body = f"{dependent_name} triggered SOS ({event_type})"
        
        data = {
            "type": NotificationChannelType.SOS_EVENT,
            "event_id": str(event_id),
            "trigger_type": "manual",
            "dependent_name": dependent_name,
            "event_type": event_type,
        }
        
        if location:
            data["lat"] = str(location.get("lat", 0))
            data["lng"] = str(location.get("lng", 0))
        
        # Add voice message URL if available (optimized flow)
        if voice_message_url:
            data["voice_message_url"] = voice_message_url
            print(f"✅ Added voice URL to notification data")
        
        print(f"📦 Final notification data: {data}")
        
        firebase_service = get_firebase_service()
        print(f"🔥 Got Firebase service: {firebase_service}")
        
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent SOS alert to {len(tokens)} guardians")

    @staticmethod
    def send_sos_acknowledged(
        tokens: List[str],
        guardian_name: str,
        event_id: int
    ) -> None:
        """
        Send acknowledgment notification
        Routes to: security_updates channel
        """
        print(f"\n🔥 send_sos_acknowledged to {len(tokens)} tokens")
        title = "✅ SOS Acknowledged"
        body = f"{guardian_name} has acknowledged your SOS alert"
        
        data = {
            "type": NotificationChannelType.SOS_ACKNOWLEDGED,
            "event_id": str(event_id),
            "guardian_name": guardian_name,
        }
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent acknowledgment to {len(tokens)} dependents")

    @staticmethod
    def send_countdown_warning(
        tokens: List[str],
        seconds_remaining: int,
        event_id: int
    ) -> None:
        """
        Send countdown warning before auto-SOS
        Routes to: security_updates channel
        """
        print(f"\n🔥 send_countdown_warning: {seconds_remaining}s to {len(tokens)} tokens")
        title = "⏰ Auto-SOS Countdown"
        body = f"Auto-SOS will trigger in {seconds_remaining} seconds. Dismiss if safe."
        
        data = {
            "type": NotificationChannelType.COUNTDOWN_WARNING,
            "event_id": str(event_id),
            "seconds_remaining": str(seconds_remaining),
        }
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent countdown warning: {seconds_remaining}s remaining")

    @staticmethod
    def send_motion_detection_alert(
        tokens: List[str],
        dependent_name: str,
        event_id: int,
        detection_type: str = "possible_fall",
        voice_message_url: Optional[str] = None
    ) -> None:
        """
        Send motion detection alert
        Routes to: sos_alerts channel (high priority)
        """
        print(f"\n🔥🔥🔥 NOTIFICATION HELPER: send_motion_detection_alert CALLED")
        print(f"📋 Tokens count: {len(tokens)}")
        print(f"📋 Dependent: {dependent_name}, Event ID: {event_id}")
        
        title = "🚨 Motion Detection Alert"
        body = f"{dependent_name}: Motion Help detected"
        
        data = {
            "type": NotificationChannelType.MOTION_DETECTION,
            "event_id": str(event_id),
            "trigger_type": "motion",
            "dependent_name": dependent_name,
            "detection_type": detection_type,
        }
        
        # Add voice message URL if available (optimized flow)
        if voice_message_url:
            data["voice_message_url"] = voice_message_url
            print(f"✅ Added voice URL to notification data")
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent motion detection alert to {len(tokens)} guardians")

    @staticmethod
    def send_tracking_notification(
        tokens: List[str],
        status: str = "active"
    ) -> None:
        """
        Send tracking service notification (low priority, persistent)
        Routes to: location_tracking channel
        """
        print(f"\n🔥 send_tracking_notification: {status} to {len(tokens)} tokens")
        title = "📍 Location Tracking"
        body = f"Background tracking is {status}"
        
        data = {
            "type": NotificationChannelType.TRACKING_ACTIVE,
            "status": status,
        }
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent tracking notification: {status}")

    @staticmethod
    def send_safety_status_update(
        tokens: List[str],
        status_message: str,
        event_id: Optional[int] = None
    ) -> None:
        """
        Send safety status update
        Routes to: security_updates channel
        """
        print(f"\n🔥 send_safety_status_update to {len(tokens)} tokens")
        title = "🔐 Safety Status"
        body = status_message
        
        data = {
            "type": NotificationChannelType.SAFETY_STATUS,
        }
        
        if event_id:
            data["event_id"] = str(event_id)
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent safety status update to {len(tokens)} users")

    @staticmethod
    def send_permission_reminder(
        tokens: List[str],
        permission_name: str
    ) -> None:
        """
        Send permission reminder
        Routes to: app_system channel
        """
        print(f"\n🔥 send_permission_reminder: {permission_name} to {len(tokens)} tokens")
        title = "⚙️ Permission Required"
        body = f"Please grant {permission_name} permission for full functionality"
        
        data = {
            "type": NotificationChannelType.PERMISSION_REQUIRED,
            "permission": permission_name,
        }
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent permission reminder: {permission_name}")

    @staticmethod
    def send_battery_warning(
        tokens: List[str],
        battery_level: int
    ) -> None:
        """
        Send battery optimization warning
        Routes to: app_system channel
        """
        print(f"\n🔥 send_battery_warning: {battery_level}% to {len(tokens)} tokens")
        title = "🔋 Battery Optimization"
        body = f"Battery at {battery_level}%. Disable optimization for reliable SOS."
        
        data = {
            "type": NotificationChannelType.BATTERY_WARNING,
            "battery_level": str(battery_level),
        }
        
        firebase_service = get_firebase_service()
        firebase_service.send_sos_notification(
            tokens=tokens,
            title=title,
            body=body,
            data=data
        )
        print(f"📨 Sent battery warning: {battery_level}%")