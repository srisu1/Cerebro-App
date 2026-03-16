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

    user = relationship("User", back_populates="subjects")
    study_sessions = relationship("StudySession", back_populates="subject", cascade="all, delete-orphan")
    quizzes = relationship("Quiz", back_populates="subject", cascade="all, delete-orphan")
    flashcards = relationship("Flashcard", back_populates="subject", cascade="all, delete-orphan")

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

    __table_args__ = (
        CheckConstraint("focus_score BETWEEN 1 AND 100", name="check_focus_score"),
    )

    user = relationship("User", back_populates="study_sessions")
    subject = relationship("Subject", back_populates="study_sessions")

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

    user = relationship("User", back_populates="quizzes")
    subject = relationship("Subject", back_populates="quizzes")

    @property
    def percentage(self):
        if self.max_score and self.max_score > 0:
            return float(self.score_achieved / self.max_score * 100)
        return 0.0

    def __repr__(self):
        return f"<Quiz {self.title} ({self.percentage:.1f}%)>"


class FlashcardDeck(Base):
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

    user = relationship("User", backref="flashcard_decks")
    subject = relationship("Subject", backref="flashcard_decks")
    flashcards = relationship("Flashcard", back_populates="deck", cascade="all, delete-orphan")

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

    # spaced repetition (SM-2)
    interval_days = Column(Integer, default=1)
    ease_factor = Column(DECIMAL(4, 2), default=2.5)
    repetitions = Column(Integer, default=0)
    next_review_date = Column(Date, default=date.today)
    last_review_date = Column(Date)

    total_reviews = Column(Integer, default=0)
    correct_reviews = Column(Integer, default=0)
    streak_days = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("difficulty BETWEEN 1 AND 5", name="check_difficulty"),
    )

    user = relationship("User", back_populates="flashcards")
    subject = relationship("Subject", back_populates="flashcards")
    deck = relationship("FlashcardDeck", back_populates="flashcards")

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
