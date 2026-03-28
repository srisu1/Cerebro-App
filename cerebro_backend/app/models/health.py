"""
CEREBRO - Health Domain Models
Sleep, Medications, Moods, Symptoms, Exercise
"""

import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text,
    ForeignKey, Date, DECIMAL, ARRAY, Time, CheckConstraint, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class SleepLog(Base):
    __tablename__ = "sleep_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    date = Column(Date, nullable=False)
    bedtime = Column(DateTime(timezone=True), nullable=False)
    wake_time = Column(DateTime(timezone=True), nullable=False)
    total_hours = Column(DECIMAL(4, 2))  # Calculated in service layer
    quality_rating = Column(Integer)
    notes = Column(Text)
    source = Column(String(50), default="manual")  # manual, google_fit
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("user_id", "date", name="unique_sleep_per_day"),
        CheckConstraint("quality_rating BETWEEN 1 AND 5", name="check_quality_rating"),
    )

    # Relationships
    user = relationship("User", back_populates="sleep_logs")

    def __repr__(self):
        return f"<SleepLog {self.date} ({self.total_hours}h)>"


class Medication(Base):
    __tablename__ = "medications"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    dosage = Column(String(100), nullable=False)
    frequency = Column(String(50), nullable=False)  # daily, weekly, as_needed
    times_of_day = Column(ARRAY(Time), default=[])
    days_of_week = Column(ARRAY(Integer), default=[1, 2, 3, 4, 5, 6, 7])
    start_date = Column(Date, default=datetime.utcnow)
    end_date = Column(Date)
    reminder_enabled = Column(Boolean, default=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="medications")
    logs = relationship("MedicationLog", back_populates="medication", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Medication {self.name} ({self.dosage})>"


class MedicationLog(Base):
    __tablename__ = "medication_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    medication_id = Column(UUID(as_uuid=True), ForeignKey("medications.id"))
    scheduled_time = Column(DateTime(timezone=True), nullable=False)
    taken_at = Column(DateTime(timezone=True))
    status = Column(String(20), nullable=False)  # taken, skipped, delayed
    side_effects = Column(Text)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    # Relationships
    medication = relationship("Medication", back_populates="logs")

    def __repr__(self):
        return f"<MedicationLog {self.status} at {self.scheduled_time}>"


class MoodDefinition(Base):
    """Pre-populated table with 8 mood types and their avatar expression assets."""
    __tablename__ = "mood_definitions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(50), nullable=False, unique=True)
    display_order = Column(Integer)
    eyes_asset_path = Column(String(200), nullable=False)
    mouth_asset_path = Column(String(200), nullable=False)
    nose_asset_path = Column(String(200))
    color = Column(String(7))  # Background color for mood sticker

    # Relationships
    entries = relationship("MoodEntry", back_populates="mood")

    def __repr__(self):
        return f"<MoodDefinition {self.name}>"


class MoodEntry(Base):
    __tablename__ = "mood_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    mood_id = Column(UUID(as_uuid=True), ForeignKey("mood_definitions.id"), nullable=False)
    timestamp = Column(DateTime(timezone=True), default=datetime.utcnow)
    note = Column(Text)
    energy_level = Column(Integer)  # 1-5
    context_tags = Column(ARRAY(String(100)), default=[])  # study, exercise, social
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("energy_level BETWEEN 1 AND 5", name="check_energy_level"),
    )

    # Relationships
    user = relationship("User", back_populates="mood_entries")
    mood = relationship("MoodDefinition", back_populates="entries")

    def __repr__(self):
        return f"<MoodEntry {self.timestamp}>"


class SymptomLog(Base):
    """Track symptoms with intensity, triggers, and relief methods for pattern detection."""
    __tablename__ = "symptom_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    symptom_type = Column(String(50), nullable=False)  # headache, fatigue, pain, nausea, etc.
    intensity = Column(Integer, nullable=False)  # 1-10 scale
    duration_minutes = Column(Integer)  # how long it lasted
    triggers = Column(ARRAY(String(100)), default=[])  # studying, lack_of_sleep, stress, caffeine, etc.
    relief_methods = Column(ARRAY(String(100)), default=[])  # rest, medication, water, stretching, etc.
    notes = Column(Text)
    recorded_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("intensity BETWEEN 1 AND 10", name="check_symptom_intensity"),
    )

    # Relationships
    user = relationship("User", back_populates="symptom_logs")

    def __repr__(self):
        return f"<SymptomLog {self.symptom_type} ({self.intensity}/10)>"


class WaterLog(Base):
    """Daily water intake tracking with goal-based progress."""
    __tablename__ = "water_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    date = Column(Date, nullable=False)
    glasses = Column(Integer, nullable=False, default=0)
    goal = Column(Integer, default=8)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("user_id", "date", name="unique_water_per_day"),
    )

    # Relationships
    user = relationship("User", back_populates="water_logs")

    def __repr__(self):
        return f"<WaterLog {self.date} ({self.glasses}/{self.goal})>"
