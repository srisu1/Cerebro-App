"""
CEREBRO - Topic Schemas

Wire shapes for the first-class Topic entity and its embedded `TopicMini`
used on content responses (materials / sessions / decks / flashcards / quizzes).
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from uuid import UUID


class TopicMini(BaseModel):
    """Compact topic view used as a sub-object on content rows."""
    id: UUID
    name: str
    color: str

    class Config:
        from_attributes = True


class TopicCreate(BaseModel):
    """Create a brand-new Topic under a given subject."""
    subject_id: UUID
    name: str = Field(..., min_length=1, max_length=200)
    color: str = Field(default="#B5C4A0", pattern=r"^#[0-9A-Fa-f]{6}$")


class TopicUpdate(BaseModel):
    """Rename or recolor a topic in place. Subject cannot move — delete and
    recreate if you need to reparent."""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")


class TopicResponse(BaseModel):
    """Full topic view with aggregate counts so the UI doesn't need N queries."""
    id: UUID
    subject_id: UUID
    name: str
    color: str
    # Timestamps are guaranteed non-null at the DB level (see migration
    # 008_enforce_topic_integrity — NOT NULL + DEFAULT NOW()). The schema
    # reflects that invariant instead of masking it with Optional.
    created_at: datetime
    updated_at: datetime

    # Aggregate item counts — computed by the router, not a DB column.
    materials_count: int = 0
    sessions_count: int = 0
    decks_count: int = 0
    flashcards_count: int = 0
    quizzes_count: int = 0
    generated_quizzes_count: int = 0
    # Convenience: total of all the above.
    total_items: int = 0

    class Config:
        from_attributes = True


class TopicAttach(BaseModel):
    """Attach a topic to a specific content item."""
    content_type: str = Field(..., pattern=r"^(material|session|deck|flashcard|quiz|generated_quiz)$")
    content_id: UUID


class TopicNameList(BaseModel):
    """Used when the client sends topic *names* rather than IDs — the server
    will find-or-create each one under the given subject."""
    subject_id: UUID
    names: List[str] = []
