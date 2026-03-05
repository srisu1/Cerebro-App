import uuid
from datetime import datetime, date
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text,
    ForeignKey, Date, ARRAY, Time
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base

class PasswordEntry(Base):
    __tablename__ = "password_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    site_name = Column(String(200), nullable=False)
    site_url = Column(String(500))
    username = Column(String(200), nullable=False)
    encrypted_password = Column(Text, nullable=False)  # AES-256 encrypted
    category = Column(String(50), default="general")  # academic, social, finance, general
    notes = Column(Text)
    last_used = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<PasswordEntry {self.site_name}>"

class HabitEntry(Base):
    __tablename__ = "habit_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(Text)
    frequency = Column(String(50), default="daily")  # daily, weekdays, weekly
    target_count = Column(Integer, default=1)  # How many times per frequency period
    color = Column(String(7), default="#10B981")
    icon = Column(String(50), default="check_circle")
    is_active = Column(Boolean, default=True)
    streak_days = Column(Integer, default=0)
    best_streak = Column(Integer, default=0)
    xp_reward = Column(Integer, default=10)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    completions = relationship("HabitCompletion", back_populates="habit", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<HabitEntry {self.name} (streak: {self.streak_days})>"

class HabitCompletion(Base):
    __tablename__ = "habit_completions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    habit_id = Column(UUID(as_uuid=True), ForeignKey("habit_entries.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    completed_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    date = Column(Date, default=date.today)
    notes = Column(Text)

    # Relationships
    habit = relationship("HabitEntry", back_populates="completions")

    def __repr__(self):
        return f"<HabitCompletion {self.date}>"

class ScheduleEntry(Base):
    __tablename__ = "schedule_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    entry_type = Column(String(50), nullable=False)  # class, exam, assignment, personal, reminder
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id"))
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True))
    location = Column(String(200))
    is_recurring = Column(Boolean, default=False)
    recurrence_rule = Column(String(200))  # e.g., "WEEKLY:MON,WED,FRI"
    reminder_minutes = Column(Integer, default=15)
    color = Column(String(7))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self):
        return f"<ScheduleEntry {self.title} ({self.entry_type})>"
