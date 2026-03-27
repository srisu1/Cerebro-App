"""
CEREBRO - Topic Domain Model

A Topic is a first-class label scoped to (user_id, subject_id). Every piece of
study content — materials, sessions, flashcard decks, flashcards, completed
quizzes, and AI-generated quizzes — can be linked to zero or more topics via
association tables. This is what powers the Topic-first grouping in the
Subject Detail page.

Why a real entity and not free-form strings:
  • Renaming a topic updates every piece of content at once.
  • Two items tagged "Photosynthesis" map to the same Topic.id — no typo
    fragmentation.
  • We can store per-topic metadata (color, mastery, target proficiency).
  • Analytics queries become joins instead of string scans.
"""

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Column, String, DateTime, ForeignKey, Table, UniqueConstraint, Index
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


def _utcnow():
    """Timezone-aware UTC "now" — matches the DateTime(timezone=True) columns
    below. Using naive datetime.utcnow() causes silent tz coercion warnings
    on Postgres and is deprecated in Python 3.12+. Defined once at module
    level so SQLAlchemy can reference it without a lambda."""
    return datetime.now(timezone.utc)


#  Association tables (pure m:n, no extra columns).
#  Each row ties one content item to one Topic.

material_topics = Table(
    "material_topics",
    Base.metadata,
    Column("material_id", UUID(as_uuid=True),
           ForeignKey("study_materials.id", ondelete="CASCADE"),
           primary_key=True),
    Column("topic_id", UUID(as_uuid=True),
           ForeignKey("topics.id", ondelete="CASCADE"),
           primary_key=True),
    Index("ix_material_topics_topic", "topic_id"),
)

session_topics = Table(
    "session_topics",
    Base.metadata,
    Column("session_id", UUID(as_uuid=True),
           ForeignKey("study_sessions.id", ondelete="CASCADE"),
           primary_key=True),
    Column("topic_id", UUID(as_uuid=True),
           ForeignKey("topics.id", ondelete="CASCADE"),
           primary_key=True),
    Index("ix_session_topics_topic", "topic_id"),
)

deck_topics = Table(
    "deck_topics",
    Base.metadata,
    Column("deck_id", UUID(as_uuid=True),
           ForeignKey("flashcard_decks.id", ondelete="CASCADE"),
           primary_key=True),
    Column("topic_id", UUID(as_uuid=True),
           ForeignKey("topics.id", ondelete="CASCADE"),
           primary_key=True),
    Index("ix_deck_topics_topic", "topic_id"),
)

flashcard_topics = Table(
    "flashcard_topics",
    Base.metadata,
    Column("flashcard_id", UUID(as_uuid=True),
           ForeignKey("flashcards.id", ondelete="CASCADE"),
           primary_key=True),
    Column("topic_id", UUID(as_uuid=True),
           ForeignKey("topics.id", ondelete="CASCADE"),
           primary_key=True),
    Index("ix_flashcard_topics_topic", "topic_id"),
)

quiz_topics = Table(
    "quiz_topics",
    Base.metadata,
    Column("quiz_id", UUID(as_uuid=True),
           ForeignKey("quizzes.id", ondelete="CASCADE"),
           primary_key=True),
    Column("topic_id", UUID(as_uuid=True),
           ForeignKey("topics.id", ondelete="CASCADE"),
           primary_key=True),
    Index("ix_quiz_topics_topic", "topic_id"),
)

generated_quiz_topics = Table(
    "generated_quiz_topics",
    Base.metadata,
    Column("generated_quiz_id", UUID(as_uuid=True),
           ForeignKey("generated_quizzes.id", ondelete="CASCADE"),
           primary_key=True),
    Column("topic_id", UUID(as_uuid=True),
           ForeignKey("topics.id", ondelete="CASCADE"),
           primary_key=True),
    Index("ix_generated_quiz_topics_topic", "topic_id"),
)


#  Topic entity

class Topic(Base):
    """
    A named topic inside a subject.

    Scoped to (user_id, subject_id). Uniqueness is enforced on the
    *normalized* name so "Photosynthesis", "photosynthesis", and
    " Photosynthesis " collapse to one row per subject.
    """
    __tablename__ = "topics"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True),
                     ForeignKey("users.id", ondelete="CASCADE"),
                     nullable=False, index=True)
    subject_id = Column(UUID(as_uuid=True),
                        ForeignKey("subjects.id", ondelete="CASCADE"),
                        nullable=False, index=True)
    # Display name — preserves original casing from first occurrence.
    name = Column(String(200), nullable=False)
    # Normalized key used for dedupe: lowercased, stripped, collapsed spaces.
    # We enforce uniqueness on this so "Photosynthesis" and "photosynthesis"
    # can never co-exist under the same subject.
    name_key = Column(String(200), nullable=False, index=True)
    color = Column(String(7), default="#B5C4A0")  # default sage

    # NOT NULL enforced at DB level by migration 008. Python-side defaults
    # belt-and-suspender the invariant — raw-SQL inserts still need to set
    # these explicitly (see migration 006 for an example), but every ORM
    # insert gets a proper tz-aware UTC timestamp automatically.
    created_at = Column(DateTime(timezone=True),
                        default=_utcnow,
                        server_default=func.now(),
                        nullable=False)
    updated_at = Column(DateTime(timezone=True),
                        default=_utcnow, onupdate=_utcnow,
                        server_default=func.now(),
                        nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "subject_id", "name_key",
                         name="uq_topic_user_subject_name"),
        Index("ix_topic_user_subject", "user_id", "subject_id"),
    )

    user = relationship("User", backref="topics")
    subject = relationship("Subject", back_populates="topics")

    materials = relationship(
        "StudyMaterial", secondary=material_topics,
        back_populates="topics", lazy="selectin")
    sessions = relationship(
        "StudySession", secondary=session_topics,
        back_populates="topics", lazy="selectin")
    decks = relationship(
        "FlashcardDeck", secondary=deck_topics,
        back_populates="topics", lazy="selectin")
    flashcards = relationship(
        "Flashcard", secondary=flashcard_topics,
        back_populates="topics", lazy="selectin")
    quizzes = relationship(
        "Quiz", secondary=quiz_topics,
        back_populates="topics", lazy="selectin")
    generated_quizzes = relationship(
        "GeneratedQuiz", secondary=generated_quiz_topics,
        back_populates="topics", lazy="selectin")

    def __repr__(self):
        return f"<Topic {self.name} (subject={self.subject_id})>"


#  Normalization helper used by the router / backfill / session hooks.
def normalize_topic_name(raw: str) -> str:
    """
    Produce the canonical name_key for a user-typed topic string.

    Rules:
      • strip leading/trailing whitespace
      • collapse runs of whitespace to a single space
      • lowercase
      • return "" for empty / whitespace-only input (caller should skip)
    """
    if raw is None:
        return ""
    s = " ".join(str(raw).split()).strip().lower()
    return s
