from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone
from typing import Optional, List
from pydantic import BaseModel
import uuid, os, json, traceback

from app.database import get_db
from app.models.user import User
from app.models.calendar import StudyEvent, GoogleCalendarToken
from app.utils.auth import get_current_user
from app.routers.notifications import create_event_notification

router = APIRouter(prefix="/study/calendar", tags=["study-calendar"])


#  SCHEMAS

class EventCreate(BaseModel):
    title: str
    description: Optional[str] = None
    event_type: str = "study"
    subject_name: Optional[str] = None
    subject_color: Optional[str] = "#9DD4F0"
    topic: Optional[str] = None
    start_time: datetime
    end_time: datetime
    all_day: bool = False
    recurring: bool = False
    recurrence_rule: Optional[str] = None

class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    event_type: Optional[str] = None
    subject_name: Optional[str] = None
    subject_color: Optional[str] = None
    topic: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    all_day: Optional[bool] = None
    completed: Optional[bool] = None
    recurring: Optional[bool] = None
    recurrence_rule: Optional[str] = None


#  CRUD ENDPOINTS

@router.get("/events")
def list_events(
    start: Optional[str] = Query(None, description="ISO start date filter"),
    end: Optional[str] = Query(None, description="ISO end date filter"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(StudyEvent).filter(StudyEvent.user_id == current_user.id)

    if start:
        try:
            start_dt = datetime.fromisoformat(start.replace("Z", "+00:00"))
            q = q.filter(StudyEvent.end_time >= start_dt)
        except ValueError:
            pass
    if end:
        try:
            end_dt = datetime.fromisoformat(end.replace("Z", "+00:00"))
            q = q.filter(StudyEvent.start_time <= end_dt)
        except ValueError:
            pass

    events = q.order_by(StudyEvent.start_time).all()
    return [_event_to_dict(e) for e in events]


@router.post("/events")
def create_event(
    body: EventCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    duration = int((body.end_time - body.start_time).total_seconds() / 60)
    event = StudyEvent(
        user_id=current_user.id,
        title=body.title,
        description=body.description,
        event_type=body.event_type,
        subject_name=body.subject_name,
        subject_color=body.subject_color or "#9DD4F0",
        topic=body.topic,
        start_time=body.start_time,
        end_time=body.end_time,
        all_day=body.all_day,
        duration_minutes=duration,
        recurring=body.recurring,
        recurrence_rule=body.recurrence_rule,
        source="manual",
    )
    db.add(event)
    db.commit()
    db.refresh(event)

    # In-app notification — lets the dashboard bell pick up the new event
    # the next time it polls. `from_ai=False` here because this endpoint
    # is what the schedule page calls for manual adds.
    try:
        create_event_notification(db, current_user, event, from_ai=False)
    except Exception as exc:  # noqa: BLE001
        print(f"[CALENDAR] Failed to create event notification: {exc}")

    # Sync to Google Calendar if connected
    _try_gcal_push(current_user, event, db)

    return _event_to_dict(event)


@router.put("/events/{event_id}")
def update_event(
    event_id: str,
    body: EventUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = (
        db.query(StudyEvent)
        .filter(StudyEvent.id == event_id, StudyEvent.user_id == current_user.id)
        .first()
    )
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    for field, value in body.dict(exclude_unset=True).items():
        setattr(event, field, value)

    if body.start_time and body.end_time:
        event.duration_minutes = int((body.end_time - body.start_time).total_seconds() / 60)
    if body.completed is True and not event.completed_at:
        event.completed_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(event)

    _try_gcal_push(current_user, event, db, update=True)

    return _event_to_dict(event)


@router.delete("/events/{event_id}")
def delete_event(
    event_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = (
        db.query(StudyEvent)
        .filter(StudyEvent.id == event_id, StudyEvent.user_id == current_user.id)
        .first()
    )
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    # Remove from Google Calendar if synced
    if event.gcal_event_id:
        _try_gcal_delete(current_user, event, db)

    db.delete(event)
    db.commit()
    return {"deleted": True}


@router.post("/generate-schedule")
def generate_smart_schedule(
    days: int = Query(default=7, ge=1, le=30),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from app.routers.analytics import _compute_analytics

    try:
        analytics = _compute_analytics(current_user, db)
    except Exception as e:
        print(f"[CALENDAR] Analytics failed: {e}")
        raise HTTPException(status_code=500, detail="Could not compute analytics for scheduling")

    sched = analytics.get("schedule", {})
    recs = sched.get("recommendations", [])

    if not recs:
        return {"events_created": 0, "message": "No study gaps to schedule — you're on track!"}

    now = datetime.now(timezone.utc)
    events_created = []

    # Distribute recommendations across the next N days
    # Prefer morning/afternoon slots, avoid weekends for heavy sessions
    study_hours = [9, 11, 14, 16]  # preferred start hours

    for day_offset in range(days):
        day = now + timedelta(days=day_offset)
        day_of_week = day.weekday()  # 0=Mon, 6=Sun

        # Fewer sessions on weekends
        max_sessions = 2 if day_of_week >= 5 else 3
        day_recs = recs[:max_sessions]

        for i, rec in enumerate(day_recs):
            hour = study_hours[i % len(study_hours)]
            start = day.replace(hour=hour, minute=0, second=0, microsecond=0)
            duration = rec.get("recommended_mins", 45)
            end = start + timedelta(minutes=duration)

            # Check for existing events at this time
            existing = (
                db.query(StudyEvent)
                .filter(
                    StudyEvent.user_id == current_user.id,
                    StudyEvent.start_time < end,
                    StudyEvent.end_time > start,
                )
                .first()
            )
            if existing:
                continue  # skip — slot occupied

            event = StudyEvent(
                user_id=current_user.id,
                title=f"Study: {rec['topic']}",
                description=rec.get("reason", ""),
                event_type=rec.get("session_type", "study"),
                subject_name=rec.get("subject_name"),
                subject_color=rec.get("subject_color", "#9DD4F0"),
                topic=rec.get("topic"),
                start_time=start,
                end_time=end,
                duration_minutes=duration,
                source="ai_schedule",
            )
            db.add(event)
            events_created.append(event)

        # Rotate recs so different topics get scheduled on different days
        recs = recs[max_sessions:] + recs[:max_sessions]

    db.commit()

    # Batch sync to Google Calendar + fan out in-app notifications.
    # We post a single consolidated "AI scheduled X sessions" notification
    # if multiple events were created — less spammy than one row per event.
    for event in events_created:
        db.refresh(event)
        _try_gcal_push(current_user, event, db)

    try:
        if len(events_created) == 1:
            create_event_notification(db, current_user, events_created[0], from_ai=True)
        elif len(events_created) > 1:
            # Roll-up — use the first event's timing in the body, but point
            # to None so the UI just opens the calendar screen.
            from app.models.notification import Notification as _N
            first = events_created[0]
            if current_user.notifications_enabled:
                rollup = _N(
                    user_id=current_user.id,
                    kind="ai_schedule",
                    title=f"AI scheduled {len(events_created)} sessions",
                    body=(f"I lined up {len(events_created)} focused blocks "
                          f"across the next {days} days — the first one is "
                          f"{_fmt_when_local(first.start_time)}."),
                    event_id=first.id,
                )
                db.add(rollup)
                db.commit()
    except Exception as exc:  # noqa: BLE001
        print(f"[CALENDAR] Failed to create AI schedule notification: {exc}")

    return {
        "events_created": len(events_created),
        "message": f"Created {len(events_created)} study sessions for the next {days} days",
        "events": [_event_to_dict(e) for e in events_created],
    }


def _fmt_when_local(dt: datetime) -> str:
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone().strftime("%A at %-I:%M%p").replace("AM", "am").replace("PM", "pm")


#  GOOGLE CALENDAR OAUTH2

# Use the same Google OAuth credentials as the main app auth
from app.config import settings as _app_settings
GCAL_CLIENT_ID = getattr(_app_settings, "GOOGLE_CLIENT_ID", "") or os.environ.get("GOOGLE_CLIENT_ID", "")
GCAL_CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")


@router.get("/gcal/status")
def gcal_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token = db.query(GoogleCalendarToken).filter(
        GoogleCalendarToken.user_id == current_user.id
    ).first()
    connected = token is not None
    return {
        "connected": connected,
        "calendar_id": token.calendar_id if token else None,
        "has_credentials": True,
    }


class GcalTokenSubmit(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    expires_in: int = 3600


@router.post("/gcal/connect")
def gcal_connect(
    body: GcalTokenSubmit,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing = db.query(GoogleCalendarToken).filter(
        GoogleCalendarToken.user_id == current_user.id
    ).first()

    if existing:
        existing.access_token = body.access_token
        if body.refresh_token:
            existing.refresh_token = body.refresh_token
        existing.token_expiry = datetime.now(timezone.utc) + timedelta(seconds=body.expires_in)
    else:
        new_token = GoogleCalendarToken(
            user_id=current_user.id,
            access_token=body.access_token,
            refresh_token=body.refresh_token,
            token_expiry=datetime.now(timezone.utc) + timedelta(seconds=body.expires_in),
        )
        db.add(new_token)

    db.commit()
    return {"status": "connected", "message": "Google Calendar connected successfully!"}


@router.post("/gcal/disconnect")
def gcal_disconnect(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    db.query(GoogleCalendarToken).filter(
        GoogleCalendarToken.user_id == current_user.id
    ).delete()
    db.commit()
    return {"status": "disconnected"}


@router.post("/gcal/sync")
def gcal_sync(
    direction: str = Query(default="both", description="push, pull, or both"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token = _get_valid_token(current_user, db)
    if not token:
        raise HTTPException(status_code=401, detail="Google Calendar not connected")

    results = {"pushed": 0, "pulled": 0, "errors": []}

    if direction in ("push", "both"):
        # Push all local events that aren't synced yet (no date filter — push everything)
        local_events = (
            db.query(StudyEvent)
            .filter(
                StudyEvent.user_id == current_user.id,
                StudyEvent.gcal_event_id.is_(None),  # not yet synced
            )
            .all()
        )
        print(f"[GCAL SYNC] Found {len(local_events)} unsynced events to push")
        for event in local_events:
            try:
                _push_event_to_gcal(token, event, db)
                results["pushed"] += 1
            except Exception as e:
                results["errors"].append(f"Push {event.title}: {e}")

    if direction in ("pull", "both"):
        # Pull events from Google Calendar
        try:
            pulled = _pull_events_from_gcal(token, current_user, db)
            results["pulled"] = pulled
        except Exception as e:
            results["errors"].append(f"Pull: {e}")

    return results


#  GOOGLE CALENDAR HELPERS

def _get_valid_token(user: User, db: Session) -> Optional[GoogleCalendarToken]:
    token = db.query(GoogleCalendarToken).filter(
        GoogleCalendarToken.user_id == user.id
    ).first()
    if not token:
        return None

    # Refresh if expired
    if token.token_expiry and token.token_expiry < datetime.now(timezone.utc):
        if token.refresh_token:
            try:
                import httpx
                r = httpx.post(
                    "https://oauth2.googleapis.com/token",
                    data={
                        "client_id": GCAL_CLIENT_ID,
                        "client_secret": GCAL_CLIENT_SECRET,
                        "refresh_token": token.refresh_token,
                        "grant_type": "refresh_token",
                    },
                    timeout=10.0,
                )
                r.raise_for_status()
                data = r.json()
                token.access_token = data["access_token"]
                token.token_expiry = datetime.now(timezone.utc) + timedelta(seconds=data.get("expires_in", 3600))
                db.commit()
            except Exception as e:
                print(f"[GCAL] Token refresh failed: {e}")
                return None
        else:
            return None

    return token


def _push_event_to_gcal(token: GoogleCalendarToken, event: StudyEvent, db: Session, update: bool = False):
    import httpx

    cal_id = token.calendar_id or "primary"

    # Ensure timestamps have timezone info (Google requires it)
    start_dt = event.start_time
    end_dt = event.end_time
    if start_dt and start_dt.tzinfo is None:
        start_dt = start_dt.replace(tzinfo=timezone.utc)
    if end_dt and end_dt.tzinfo is None:
        end_dt = end_dt.replace(tzinfo=timezone.utc)

    gcal_body = {
        "summary": event.title,
        "description": event.description or f"CEREBRO study session\nType: {event.event_type}\nTopic: {event.topic or 'General'}",
        "start": {"dateTime": start_dt.isoformat(), "timeZone": "UTC"},
        "end": {"dateTime": end_dt.isoformat(), "timeZone": "UTC"},
        "colorId": _gcal_color_id(event.event_type),
        "reminders": {"useDefault": False, "overrides": [{"method": "popup", "minutes": 10}]},
    }

    headers = {"Authorization": f"Bearer {token.access_token}", "Content-Type": "application/json"}

    print(f"[GCAL] Pushing event '{event.title}' to calendar '{cal_id}'...")

    if update and event.gcal_event_id:
        r = httpx.put(
            f"https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events/{event.gcal_event_id}",
            headers=headers, json=gcal_body, timeout=10.0,
        )
    else:
        r = httpx.post(
            f"https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events",
            headers=headers, json=gcal_body, timeout=10.0,
        )

    if r.status_code == 403:
        error_detail = r.text
        print(f"[GCAL] Push FAILED (403 Forbidden): {error_detail}")
        raise Exception(
            "Google Calendar API not enabled or permission denied. "
            "Go to console.cloud.google.com → APIs & Services → Library → "
            "search 'Google Calendar API' → Enable it."
        )
    if r.status_code >= 400:
        print(f"[GCAL] Push FAILED ({r.status_code}): {r.text}")
    r.raise_for_status()
    gcal_data = r.json()

    event.gcal_event_id = gcal_data["id"]
    event.gcal_calendar_id = cal_id
    event.gcal_synced_at = datetime.now(timezone.utc)
    db.commit()
    print(f"[GCAL] Push OK — gcal_event_id={gcal_data['id']}")


def _try_gcal_push(user: User, event: StudyEvent, db: Session, update: bool = False):
    try:
        token = _get_valid_token(user, db)
        if token:
            _push_event_to_gcal(token, event, db, update=update)
        else:
            print(f"[GCAL] No valid token for user {user.id} — skipping push for '{event.title}'")
    except Exception as e:
        import traceback
        print(f"[GCAL] Push failed for '{event.title}': {e}")
        traceback.print_exc()


def _try_gcal_delete(user: User, event: StudyEvent, db: Session):
    try:
        token = _get_valid_token(user, db)
        if token and event.gcal_event_id:
            import httpx
            cal_id = event.gcal_calendar_id or token.calendar_id or "primary"
            httpx.delete(
                f"https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events/{event.gcal_event_id}",
                headers={"Authorization": f"Bearer {token.access_token}"},
                timeout=10.0,
            )
    except Exception as e:
        print(f"[GCAL] Delete failed: {e}")


def _pull_events_from_gcal(token: GoogleCalendarToken, user: User, db: Session) -> int:
    import httpx

    cal_id = token.calendar_id or "primary"
    now = datetime.now(timezone.utc)
    time_min = now.isoformat()
    time_max = (now + timedelta(days=30)).isoformat()

    r = httpx.get(
        f"https://www.googleapis.com/calendar/v3/calendars/{cal_id}/events",
        headers={"Authorization": f"Bearer {token.access_token}"},
        params={"timeMin": time_min, "timeMax": time_max, "maxResults": 50,
                "singleEvents": True, "orderBy": "startTime"},
        timeout=15.0,
    )
    if r.status_code == 403:
        raise Exception(
            "Google Calendar API not enabled. "
            "Enable it at console.cloud.google.com → APIs & Services → Library → Google Calendar API"
        )
    r.raise_for_status()
    gcal_events = r.json().get("items", [])

    imported = 0
    for ge in gcal_events:
        gcal_id = ge["id"]
        # Skip if already imported
        existing = db.query(StudyEvent).filter(
            StudyEvent.user_id == user.id,
            StudyEvent.gcal_event_id == gcal_id,
        ).first()
        if existing:
            # Update existing
            existing.title = ge.get("summary", existing.title)
            existing.description = ge.get("description", existing.description)
            start_str = ge.get("start", {}).get("dateTime") or ge.get("start", {}).get("date")
            end_str = ge.get("end", {}).get("dateTime") or ge.get("end", {}).get("date")
            if start_str:
                existing.start_time = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
            if end_str:
                existing.end_time = datetime.fromisoformat(end_str.replace("Z", "+00:00"))
            continue

        # Create new local event from Google Calendar
        start_str = ge.get("start", {}).get("dateTime") or ge.get("start", {}).get("date")
        end_str = ge.get("end", {}).get("dateTime") or ge.get("end", {}).get("date")
        if not start_str or not end_str:
            continue

        start_dt = datetime.fromisoformat(start_str.replace("Z", "+00:00"))
        end_dt = datetime.fromisoformat(end_str.replace("Z", "+00:00"))

        all_day = "date" in ge.get("start", {}) and "dateTime" not in ge.get("start", {})

        event = StudyEvent(
            user_id=user.id,
            title=ge.get("summary", "Google Calendar Event"),
            description=ge.get("description"),
            event_type="imported",
            start_time=start_dt,
            end_time=end_dt,
            all_day=all_day,
            duration_minutes=int((end_dt - start_dt).total_seconds() / 60),
            gcal_event_id=gcal_id,
            gcal_calendar_id=cal_id,
            gcal_synced_at=datetime.now(timezone.utc),
            source="gcal_import",
        )
        db.add(event)
        imported += 1

    db.commit()
    return imported


def _gcal_color_id(event_type: str) -> str:
    # Google Calendar color IDs: 1-11
    return {
        "study": "9",       # blueberry
        "review": "2",      # sage
        "quiz": "6",        # tangerine
        "flashcard": "3",   # grape
        "break": "7",       # peacock
        "exam": "11",       # tomato
        "imported": "8",    # graphite
    }.get(event_type, "9")


#  HELPERS

def _event_to_dict(e: StudyEvent) -> dict:
    return {
        "id": str(e.id),
        "title": e.title,
        "description": e.description,
        "event_type": e.event_type,
        "subject_name": e.subject_name,
        "subject_color": e.subject_color,
        "topic": e.topic,
        "start_time": e.start_time.isoformat() if e.start_time else None,
        "end_time": e.end_time.isoformat() if e.end_time else None,
        "all_day": e.all_day,
        "duration_minutes": e.duration_minutes,
        "recurring": e.recurring,
        "completed": e.completed,
        "completed_at": e.completed_at.isoformat() if e.completed_at else None,
        "gcal_synced": e.gcal_event_id is not None,
        "source": e.source,
    }
