"""
CEREBRO - User Model
Central user table with authentication fields and profile data.
"""

import uuid
from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, Integer, Text, Time, Float
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    email = Column(String(255), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=True)  # Nullable for OAuth-only users
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)

    google_id = Column(String(255), unique=True, nullable=True, index=True)
    auth_provider = Column(String(50), default="email")  # "email" or "google"
    avatar_url = Column(String(500), nullable=True)  # Google profile picture

    display_name = Column(String(100), nullable=False)
    institution_type = Column(String(50))  # school, college, sixth_form, university
    university = Column(String(200))       # institution name (any type)
    course = Column(String(200))           # course / program / stream
    year_of_study = Column(Integer)
    bio = Column(Text)
    # Wizard-collected academic context — used by the smart study system
    # for recommendations, study-hour suggestions, and quiz generation.
    degree_level = Column(String(50))      # undergraduate, masters, phd
    affiliation = Column(String(300))      # e.g. "Affiliated with London Met University"

    daily_study_hours = Column(Float)              # target hours per day
    study_goals = Column(ARRAY(String(100)), default=[])  # e.g. ["Pass exams", "Improve grades"]

    bedtime = Column(Time)                          # user's typical bedtime
    wake_time = Column(Time)                        # user's typical wake time
    sleep_hours_target = Column(Float)              # derived target sleep hours

    initial_mood = Column(String(50))               # name from MoodDefinition (Happy, Sad, ...)

    initial_habits = Column(ARRAY(String(100)), default=[])

    # Used to personalise the symptom picker, surface relevant insights,
    # and cross-reference with sleep/mood correlations. Medications live in
    # the dedicated `medications` table so they can track doses + adherence.
    medical_conditions = Column(ARRAY(String(100)), default=[])
    allergies = Column(ARRAY(String(100)), default=[])

    total_xp = Column(Integer, default=0)
    level = Column(Integer, default=1)
    streak_days = Column(Integer, default=0)
    coins = Column(Integer, default=0)

    # notifications_enabled — master in-app switch (bell tray + pill count).
    # daily_reminders_enabled — when true, day-before event reminders also
    #   trigger an email (reuses forgot-password SMTP transport).
    notifications_enabled = Column(Boolean, default=True, nullable=False)
    daily_reminders_enabled = Column(Boolean, default=True, nullable=False)

    reset_token = Column(String(255), nullable=True)
    reset_token_expires = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = Column(DateTime(timezone=True))

    subjects = relationship("Subject", back_populates="user", cascade="all, delete-orphan")
    study_sessions = relationship("StudySession", back_populates="user", cascade="all, delete-orphan")
    quizzes = relationship("Quiz", back_populates="user", cascade="all, delete-orphan")
    flashcards = relationship("Flashcard", back_populates="user", cascade="all, delete-orphan")
    sleep_logs = relationship("SleepLog", back_populates="user", cascade="all, delete-orphan")
    medications = relationship("Medication", back_populates="user", cascade="all, delete-orphan")
    mood_entries = relationship("MoodEntry", back_populates="user", cascade="all, delete-orphan")
    symptom_logs = relationship("SymptomLog", back_populates="user", cascade="all, delete-orphan")
    water_logs = relationship("WaterLog", back_populates="user", cascade="all, delete-orphan")
    avatar = relationship("UserAvatar", back_populates="user", uselist=False, cascade="all, delete-orphan")
    achievements = relationship("UserAchievement", back_populates="user", cascade="all, delete-orphan")
    xp_transactions = relationship("XPTransaction", back_populates="user", cascade="all, delete-orphan")

    @property
    def has_password(self) -> bool:
        """Whether this user has set a password (vs OAuth-only)."""
        return self.hashed_password is not None

    def __repr__(self):
        return f"<User {self.display_name} ({self.email})>"
