"""
CEREBRO — Notification Model
In-app notifications surfaced in the dashboard notification bell.

A notification is created when:
  • A user schedules a study event manually
  • The AI scheduler creates events
  • A day-before reminder is computed (lazy — see routers/notifications.py)
  • A Google Calendar import brings in new events

Day-before reminders optionally trigger an email if the user has
`daily_reminders_enabled = True` — that path reuses the forgot-password
SMTP transport in app.utils.email.
"""

import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Text,
    ForeignKey, Index,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Notification(Base):
    """One in-app notification row — maps 1:1 to a bell-tray entry."""
    __tablename__ = "notifications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # Classification — drives icon / color in the UI
    #   event_created   — "You scheduled X for Tuesday 2pm"
    #   event_reminder  — "Heads up: X starts tomorrow at 2pm"
    #   ai_schedule     — "I booked 3 study sessions for next week"
    #   system          — generic fallback
    kind = Column(String(40), nullable=False, default="system")

    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)

    # Optional deep-link payload. For event notifications we stash the
    # StudyEvent id so tapping a notification can jump to the event.
    event_id = Column(UUID(as_uuid=True), nullable=True)

    # Idempotency key — lets the "day-before reminder" computation be
    # run on every dashboard fetch without duplicating rows. Format:
    #   "event_reminder:<event_id>:<YYYY-MM-DD>"
    dedupe_key = Column(String(200), nullable=True, unique=False, index=True)

    # Mark-as-read + email delivery tracking
    read = Column(Boolean, default=False, nullable=False)
    read_at = Column(DateTime(timezone=True))
    email_sent = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    user = relationship("User", backref="notifications")

    __table_args__ = (
        Index("ix_notifications_user_created", "user_id", "created_at"),
        Index("ix_notifications_dedupe", "user_id", "dedupe_key"),
    )

    def __repr__(self):
        return f"<Notification {self.kind} {self.title!r} user={self.user_id}>"
