from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from pydantic import BaseModel
from uuid import UUID

from app.database import get_db
from app.models.user import User
from app.models.notification import Notification
from app.models.calendar import StudyEvent
from app.utils.auth import get_current_user
from app.utils.email import send_event_reminder_email


router = APIRouter(prefix="/notifications", tags=["notifications"])


#  SCHEMAS

class NotificationOut(BaseModel):
    id: UUID
    kind: str
    title: str
    body: str
    event_id: Optional[UUID] = None
    read: bool
    created_at: datetime

    class Config:
        from_attributes = True


#  HELPERS

def _fmt_when(dt: datetime) -> str:
    # Guard against naive datetimes sneaking in from SQLite.
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    local = dt.astimezone()  # render in the server's local tz
    return local.strftime("%A at %-I:%M%p").replace("AM", "am").replace("PM", "pm")


def _materialize_reminders(user: User, db: Session) -> int:
    if not user.notifications_enabled:
        return 0

    now = datetime.now(timezone.utc)
    window_end = now + timedelta(hours=24)

    upcoming = (
        db.query(StudyEvent)
        .filter(
            StudyEvent.user_id == user.id,
            StudyEvent.start_time > now,
            StudyEvent.start_time <= window_end,
            StudyEvent.completed.is_(False),
        )
        .all()
    )

    if not upcoming:
        return 0

    today_key = now.strftime("%Y-%m-%d")
    inserted = 0
    for event in upcoming:
        dedupe = f"event_reminder:{event.id}:{today_key}"
        existing = (
            db.query(Notification)
            .filter(
                Notification.user_id == user.id,
                Notification.dedupe_key == dedupe,
            )
            .first()
        )
        if existing:
            continue

        when = _fmt_when(event.start_time)
        notif = Notification(
            user_id=user.id,
            kind="event_reminder",
            title=f"Tomorrow: {event.title}",
            body=f"Starts {when}. "
                 + (f"Topic: {event.topic}. " if event.topic else "")
                 + "Tap to review what's coming up.",
            event_id=event.id,
            dedupe_key=dedupe,
        )
        db.add(notif)
        inserted += 1

        # Email delivery — best effort, never blocks the API response.
        # We set email_sent=True first so a transient SMTP failure doesn't
        # make every subsequent request retry forever; we'd rather drop a
        # single email than spam the inbox.
        if user.daily_reminders_enabled and user.email:
            try:
                ok = send_event_reminder_email(
                    to_email=user.email,
                    display_name=user.display_name or "there",
                    event_title=event.title,
                    event_when=when,
                    event_topic=event.topic or "",
                )
                notif.email_sent = ok
            except Exception as exc:  # noqa: BLE001
                print(f"[NOTIF] Email send raised: {exc}")
                notif.email_sent = False

    if inserted:
        db.commit()
    return inserted


def create_event_notification(
    db: Session,
    user: User,
    event: StudyEvent,
    *,
    from_ai: bool = False,
) -> Optional[Notification]:
    if not user.notifications_enabled:
        return None

    when = _fmt_when(event.start_time)
    kind = "ai_schedule" if from_ai else "event_created"
    if from_ai:
        title = f"AI scheduled: {event.title}"
        body = (f"I booked a {event.duration_minutes or 45}-min session for "
                f"{when}. You can always edit or move it.")
    else:
        title = f"Scheduled: {event.title}"
        body = f"Added to your calendar for {when}."

    notif = Notification(
        user_id=user.id,
        kind=kind,
        title=title,
        body=body,
        event_id=event.id,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif


#  ENDPOINTS

@router.get("", response_model=List[NotificationOut])
def list_notifications(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _materialize_reminders(current_user, db)

    rows = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(min(limit, 200))
        .all()
    )
    return rows


@router.get("/unread-count")
def unread_count(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _materialize_reminders(current_user, db)
    count = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.read.is_(False),
        )
        .count()
    )
    return {"count": count}


@router.post("/{notif_id}/read")
def mark_read(
    notif_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notif = (
        db.query(Notification)
        .filter(Notification.id == notif_id, Notification.user_id == current_user.id)
        .first()
    )
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    if not notif.read:
        notif.read = True
        notif.read_at = datetime.now(timezone.utc)
        db.commit()
    return {"ok": True}


@router.post("/mark-all-read")
def mark_all_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.read.is_(False),
        )
        .update(
            {"read": True, "read_at": datetime.now(timezone.utc)},
            synchronize_session=False,
        )
    )
    db.commit()
    return {"ok": True}


@router.delete("/{notif_id}")
def dismiss(
    notif_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    notif = (
        db.query(Notification)
        .filter(Notification.id == notif_id, Notification.user_id == current_user.id)
        .first()
    )
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    db.delete(notif)
    db.commit()
    return {"ok": True}
