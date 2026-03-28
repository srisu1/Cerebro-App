"""
CEREBRO — Study Calendar Models
StudyEvent: local study schedule events with optional Google Calendar sync
GoogleCalendarToken: OAuth2 tokens for Google Calendar API
"""

import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text,
    ForeignKey, ARRAY
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class StudyEvent(Base):
    """A scheduled study event — can sync with Google Calendar."""
    __tablename__ = "study_events"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(300), nullable=False)
    description = Column(Text)
    event_type = Column(String(50), default="study")  # study, review, quiz, flashcard, break, exam
    subject_name = Column(String(200))
    subject_color = Column(String(7), default="#9DD4F0")
    topic = Column(String(200))  # optional: specific topic to study

    # Timing
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=False)
    all_day = Column(Boolean, default=False)
    duration_minutes = Column(Integer)

    # Recurrence
    recurring = Column(Boolean, default=False)
    recurrence_rule = Column(String(200))  # RRULE string like "FREQ=WEEKLY;BYDAY=MO,WE,FR"

    # Status
    completed = Column(Boolean, default=False)
    completed_at = Column(DateTime(timezone=True))

    # Google Calendar sync
    gcal_event_id = Column(String(300))  # Google Calendar event ID (if synced)
    gcal_calendar_id = Column(String(300))  # Google Calendar ID
    gcal_synced_at = Column(DateTime(timezone=True))

    # Source tracking
    source = Column(String(50), default="manual")  # manual, ai_schedule, analytics, gcal_import

    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", backref="study_events")

    def __repr__(self):
        return f"<StudyEvent {self.title} @ {self.start_time}>"


class GoogleCalendarToken(Base):
    """Stores OAuth2 tokens for Google Calendar integration per user."""
    __tablename__ = "google_calendar_tokens"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    access_token = Column(Text, nullable=False)
    refresh_token = Column(Text)
    token_expiry = Column(DateTime(timezone=True))
    calendar_id = Column(String(300), default="primary")  # which calendar to sync with
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", backref="gcal_token")

    def __repr__(self):
        return f"<GoogleCalendarToken user={self.user_id}>"
