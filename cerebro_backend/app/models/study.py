"""
CEREBRO - Study Domain Models
Subjects, Study Sessions, Quizzes, Flashcards, Resources
"""

import uuid
from datetime import datetime, date
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text,
    ForeignKey, Date, DECIMAL, ARRAY, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name = Column(String(100), nullable=False)
    code = Column(String(50))
    color = Column(String(7), default="#4F46E5")
    icon = Column(String(50), default="book")
    current_proficiency = Column(DECIMAL(5, 2), default=0.0)
    target_proficiency = Column(DECIMAL(5, 2), default=100.0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="subjects")
    study_sessions = relationship("StudySession", back_populates="subject", cascade="all, delete-orphan")
    quizzes = relationship("Quiz", back_populates="subject", cascade="all, delete-orphan")
    flashcards = relationship("Flashcard", back_populates="subject", cascade="all, delete-orphan")
    topics = relationship("Topic", back_populates="subject",
                          cascade="all, delete-orphan", lazy="selectin")

    def __repr__(self):
        return f"<Subject {self.name} ({self.code})>"


class StudySession(Base):
    __tablename__ = "study_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id"))
    title = Column(String(200))
    session_type = Column(String(50), nullable=False)  # focused, review, practice, lecture
    duration_minutes = Column(Integer, nullable=False)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True))
    focus_score = Column(Integer)
    topics_covered = Column(ARRAY(String(200)), default=[])
    notes = Column(Text)
    xp_earned = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    # Live session lifecycle tracking (Option B — persistent session state)
    # status: "running" (actively studying), "paused" (timer stopped but session alive),
    #         "completed" (session finalized — the default terminal state)
    status = Column(String(20), default="completed", nullable=False)
    paused_at = Column(DateTime(timezone=True))
    total_paused_seconds = Column(Integer, default=0, nullable=False)
    distractions = Column(Integer, default=0, nullable=False)

    __table_args__ = (
        CheckConstraint("focus_score BETWEEN 1 AND 100", name="check_focus_score"),
        CheckConstraint(
            "status IN ('running', 'paused', 'completed')",
            name="check_session_status",
        ),
    )

    # Relationships
    user = relationship("User", back_populates="study_sessions")
    subject = relationship("Subject", back_populates="study_sessions")
    topics = relationship(
        "Topic", secondary="session_topics",
        back_populates="sessions", lazy="selectin")

    def __repr__(self):
        return f"<StudySession {self.title} ({self.duration_minutes}min)>"


class Quiz(Base):
    __tablename__ = "quizzes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id"))
    title = Column(String(200), nullable=False)
    quiz_type = Column(String(50))  # test, assignment, mock, practice
    score_achieved = Column(DECIMAL(5, 2), nullable=False)
    max_score = Column(DECIMAL(5, 2), nullable=False)
    topics_tested = Column(ARRAY(String(200)), default=[])
    weak_topics = Column(ARRAY(String(200)), default=[])
    date_taken = Column(Date, nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    # Relationships
    user = relationship("User", back_populates="quizzes")
    subject = relationship("Subject", back_populates="quizzes")
    topics = relationship(
        "Topic", secondary="quiz_topics",
        back_populates="quizzes", lazy="selectin")

    @property
    def percentage(self):
        if self.max_score and self.max_score > 0:
            return float(self.score_achieved / self.max_score * 100)
        return 0.0

    def __repr__(self):
        return f"<Quiz {self.title} ({self.percentage:.1f}%)>"


class FlashcardDeck(Base):
    """A collection of flashcards that can be reviewed and tracked together."""
    __tablename__ = "flashcard_decks"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id", ondelete="SET NULL"))
    name = Column(String(200), nullable=False)
    description = Column(Text, default="")
    color = Column(String(7), default="#A8D5A3")
    icon = Column(String(50), default="layers")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", backref="flashcard_decks")
    subject = relationship("Subject", backref="flashcard_decks")
    flashcards = relationship("Flashcard", back_populates="deck", cascade="all, delete-orphan")
    topics = relationship(
        "Topic", secondary="deck_topics",
        back_populates="decks", lazy="selectin")

    def __repr__(self):
        return f"<FlashcardDeck {self.name}>"


class Flashcard(Base):
    __tablename__ = "flashcards"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id"))
    deck_id = Column(UUID(as_uuid=True), ForeignKey("flashcard_decks.id", ondelete="CASCADE"), nullable=True)
    front_text = Column(Text, nullable=False)
    back_text = Column(Text, nullable=False)
    tags = Column(ARRAY(String(100)), default=[])
    difficulty = Column(Integer, default=3)

    # SM-2 Spaced Repetition fields
    interval_days = Column(Integer, default=1)
    ease_factor = Column(DECIMAL(4, 2), default=2.5)
    repetitions = Column(Integer, default=0)
    next_review_date = Column(Date, default=date.today)
    last_review_date = Column(Date)

    # Performance tracking
    total_reviews = Column(Integer, default=0)
    correct_reviews = Column(Integer, default=0)
    streak_days = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("difficulty BETWEEN 1 AND 5", name="check_difficulty"),
    )

    # Relationships
    user = relationship("User", back_populates="flashcards")
    subject = relationship("Subject", back_populates="flashcards")
    deck = relationship("FlashcardDeck", back_populates="flashcards")
    topics = relationship(
        "Topic", secondary="flashcard_topics",
        back_populates="flashcards", lazy="selectin")

    def __repr__(self):
        return f"<Flashcard {self.front_text[:30]}...>"


class Resource(Base):
    __tablename__ = "resources"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(200), nullable=False)
    url = Column(String(500), nullable=False)
    resource_type = Column(String(50))  # video, article, tutorial, practice
    subject = Column(String(100))
    topics = Column(ARRAY(String(200)), default=[])
    difficulty = Column(String(20))  # beginner, intermediate, advanced
    description = Column(Text)
    opened_count = Column(Integer, default=0)
    helpful_rating = Column(DECIMAL(3, 2), default=0.0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    def __repr__(self):
        return f"<Resource {self.title}>"


class ResourceRecommendation(Base):
    """Cached AI-generated learning resource recommendations (6-hour TTL)."""
    __tablename__ = "resource_recommendations"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    recommendations_data = Column(Text, nullable=False)  # JSON blob of categorized recs
    generated_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    expires_at = Column(DateTime(timezone=True), nullable=False)  # generated_at + 6 hours
    analysis_snapshot = Column(Text)  # JSON: weak areas snapshot at generation time
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User", backref="resource_recommendations")

    def __repr__(self):
        return f"<ResourceRecommendation user={self.user_id} expires={self.expires_at}>"
