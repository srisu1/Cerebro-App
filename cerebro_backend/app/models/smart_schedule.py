"""
CEREBRO — Smart Schedule Models
SmartScheduleConfig: per-user prefs for the universal AI scheduler.

The actual proposed/committed blocks live as `StudyEvent` rows
(source="ai_schedule") so they automatically appear in the Study Calendar
and round-trip through Google Calendar via the existing infra.
"""

import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer,
    ForeignKey,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class SmartScheduleConfig(Base):
    """User-tunable knobs for the smart universal scheduler.

    One row per user. The scheduler reads this + their analytics
    (peak-focus hours, due flashcards, due quizzes, weak subjects) and
    proposes a 1-week plan that fits around existing calendar events.
    """
    __tablename__ = "smart_schedule_configs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, unique=True,
    )

    # If a toggle is off the scheduler won't propose that activity.
    enable_focus_sessions = Column(Boolean, default=True)
    enable_flashcards     = Column(Boolean, default=True)
    enable_quizzes        = Column(Boolean, default=True)
    enable_light_review   = Column(Boolean, default=True)

    focus_sessions_per_week     = Column(Integer, default=4)
    focus_session_minutes       = Column(Integer, default=45)
    flashcard_blocks_per_week   = Column(Integer, default=3)
    flashcard_block_minutes     = Column(Integer, default=15)
    quiz_blocks_per_week        = Column(Integer, default=1)
    quiz_block_minutes          = Column(Integer, default=20)
    light_review_blocks_per_week= Column(Integer, default=2)
    light_review_minutes        = Column(Integer, default=20)

    preferred_start_hour = Column(Integer, default=9)   # 09:00
    preferred_end_hour   = Column(Integer, default=22)  # 22:00
    avoid_weekends       = Column(Boolean, default=False)

    # If true, scheduler reads the user's Google Calendar before slotting.
    respect_google_calendar = Column(Boolean, default=True)
    # Minimum gap (minutes) between two scheduled blocks
    min_gap_minutes        = Column(Integer, default=15)

    last_plan_generated_at = Column(DateTime(timezone=True))
    last_plan_committed_at = Column(DateTime(timezone=True))
    enabled                = Column(Boolean, default=True)

    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", backref="smart_schedule_config")

    def __repr__(self):
        return f"<SmartScheduleConfig user={self.user_id} enabled={self.enabled}>"
