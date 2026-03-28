"""
CEREBRO - Study Domain Schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date
from uuid import UUID
from decimal import Decimal

from app.schemas.topic import TopicMini


class SubjectCreate(BaseModel):
    name: str = Field(..., max_length=100)
    code: Optional[str] = Field(None, max_length=50)
    color: str = Field(default="#4F46E5", pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: str = Field(default="book", max_length=50)
    target_proficiency: Decimal = Field(default=100.0, ge=0, le=100)


class SubjectResponse(BaseModel):
    id: UUID
    name: str
    code: Optional[str]
    color: str
    icon: str
    current_proficiency: Decimal
    target_proficiency: Decimal
    created_at: datetime
    # These are *derived* — not stored on the Subject row. The router
    # populates them from the subject.topics relationship on read so
    # the UI can render "X/Y topics" without a second round-trip.
    topics_total: int = 0
    topics_mastered: int = 0

    class Config:
        from_attributes = True


class SubjectUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    code: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: Optional[str] = Field(None, max_length=50)
    target_proficiency: Optional[Decimal] = Field(None, ge=0, le=100)


class StudySessionCreate(BaseModel):
    subject_id: Optional[UUID] = None
    title: Optional[str] = Field(None, max_length=200)
    session_type: str = Field(..., pattern=r"^(focused|review|practice|lecture)$")
    duration_minutes: int = Field(..., ge=1, le=720)
    start_time: datetime
    end_time: Optional[datetime] = None
    focus_score: Optional[int] = Field(None, ge=1, le=100)
    topics_covered: List[str] = []
    notes: Optional[str] = None


class StudySessionResponse(BaseModel):
    id: UUID
    subject_id: Optional[UUID]
    title: Optional[str]
    session_type: str
    duration_minutes: int
    start_time: datetime
    end_time: Optional[datetime]
    focus_score: Optional[int]
    topics_covered: List[str]
    notes: Optional[str]
    xp_earned: int
    created_at: datetime
    # Live lifecycle fields — tracked by the Option B global session provider.
    # `status` is the source of truth for "is a session currently live?" — any
    # value other than 'completed' means the hero should render the mini-player.
    status: str = "completed"
    paused_at: Optional[datetime] = None
    total_paused_seconds: int = 0
    distractions: int = 0
    # First-class Topic references — replaces raw topics_covered strings on the
    # client side. UI should prefer topic_refs for chips, grouping, and filters.
    topic_refs: List[TopicMini] = Field(default_factory=list, validation_alias="topics")

    class Config:
        from_attributes = True
        populate_by_name = True


class StudySessionUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    notes: Optional[str] = None
    topics_covered: Optional[List[str]] = None
    focus_score: Optional[int] = Field(None, ge=1, le=100)


# These schemas drive the /study/sessions/start|pause|resume|end|active
# endpoints. The contract is intentionally *minimal* on start — the client
# creates a blank canvas, then fills in focus_score/notes/topics only when
# the session ends. Mid-session edits can use the regular StudySessionUpdate
# path if needed.

class SessionStartRequest(BaseModel):
    """Payload to open a fresh live session.

    `planned_duration_minutes` is the user's *target* — we store it on the
    row immediately so the hero can show "00:12 / 25:00" progress, but the
    final `duration_minutes` is recomputed from (end_time - start_time -
    total_paused_seconds) on /end. Clients may omit it for open-ended
    sessions (we default to 25, the Pomodoro unit).
    """
    subject_id: Optional[UUID] = None
    title: Optional[str] = Field(None, max_length=200)
    session_type: str = Field(default="focused",
                              pattern=r"^(focused|review|practice|lecture)$")
    planned_duration_minutes: int = Field(default=25, ge=1, le=720)
    topics_covered: List[str] = []


class SessionEndRequest(BaseModel):
    """Payload to finalize a live session. All fields optional.

    Leaving `focus_score` None tells the router to auto-derive it from the
    distraction count so we always have *some* metric to surface on history.
    """
    focus_score: Optional[int] = Field(None, ge=1, le=100)
    notes: Optional[str] = None
    topics_covered: Optional[List[str]] = None


class ActiveSessionResponse(StudySessionResponse):
    """Response for GET /study/sessions/active.

    Extends StudySessionResponse with a pre-computed `elapsed_seconds` so the
    client doesn't need to do the arithmetic (and to survive client clock
    drift — the server is always the source of truth for "how long has this
    session been running"). Returns null when no session is active; the
    router handles that case with a 204.
    """
    elapsed_seconds: int = 0


class QuizCreate(BaseModel):
    subject_id: Optional[UUID] = None
    title: str = Field(..., max_length=200)
    quiz_type: Optional[str] = None
    score_achieved: Decimal = Field(..., ge=0)
    max_score: Decimal = Field(..., gt=0)
    topics_tested: List[str] = []
    weak_topics: List[str] = []
    date_taken: date


class QuizResponse(BaseModel):
    id: UUID
    subject_id: Optional[UUID]
    title: str
    quiz_type: Optional[str]
    score_achieved: Decimal
    max_score: Decimal
    percentage: float
    topics_tested: List[str]
    weak_topics: List[str]
    date_taken: date
    created_at: datetime
    topic_refs: List[TopicMini] = Field(default_factory=list, validation_alias="topics")

    class Config:
        from_attributes = True
        populate_by_name = True


class FlashcardDeckCreate(BaseModel):
    subject_id: Optional[UUID] = None
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = ""
    color: str = Field(default="#A8D5A3", pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: str = Field(default="layers", max_length=50)


class FlashcardDeckUpdate(BaseModel):
    # subject_id is intentionally included here (it lives on Create already)
    # so existing decks created before subject_id was surfaced in the UI
    # can be reassigned to a subject via the Edit Deck dialog without
    # having to delete+recreate. Keep it Optional so the caller can omit
    # it entirely for partial updates.
    subject_id: Optional[UUID] = None
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    description: Optional[str] = None
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: Optional[str] = Field(None, max_length=50)


class FlashcardDeckResponse(BaseModel):
    id: UUID
    subject_id: Optional[UUID]
    name: str
    description: Optional[str]
    color: str
    icon: str
    card_count: int = 0
    due_count: int = 0
    mastery_pct: float = 0.0
    created_at: datetime
    updated_at: Optional[datetime]
    topic_refs: List[TopicMini] = Field(default_factory=list, validation_alias="topics")

    class Config:
        from_attributes = True
        populate_by_name = True


class FlashcardCreate(BaseModel):
    subject_id: Optional[UUID] = None
    deck_id: Optional[UUID] = None
    front_text: str = Field(..., min_length=1)
    back_text: str = Field(..., min_length=1)
    tags: List[str] = []
    difficulty: int = Field(default=3, ge=1, le=5)


class FlashcardResponse(BaseModel):
    id: UUID
    subject_id: Optional[UUID]
    deck_id: Optional[UUID]
    front_text: str
    back_text: str
    tags: List[str]
    difficulty: int
    interval_days: int
    ease_factor: Decimal
    repetitions: int
    next_review_date: date
    total_reviews: int
    correct_reviews: int
    streak_days: int
    created_at: datetime
    topic_refs: List[TopicMini] = Field(default_factory=list, validation_alias="topics")

    class Config:
        from_attributes = True
        populate_by_name = True


class FlashcardUpdate(BaseModel):
    """Partial update for a flashcard. All fields optional so the UI can
    patch a single field at a time — the router uses
    `model_dump(exclude_unset=True)` to avoid clobbering fields the
    caller didn't send. `subject_id` and `deck_id` accept an explicit
    null so the edit dialog can detach a card from a subject/deck
    without having to delete and recreate it.

    Note: SRS state (interval_days, ease_factor, repetitions, review
    dates, total_reviews, correct_reviews) is intentionally NOT editable
    here — that belongs to the review endpoint. Letting a user nudge
    those directly would corrupt the spaced-repetition signal.
    """
    front_text: Optional[str] = Field(None, min_length=1)
    back_text: Optional[str] = Field(None, min_length=1)
    subject_id: Optional[UUID] = None
    deck_id: Optional[UUID] = None
    tags: Optional[List[str]] = None
    difficulty: Optional[int] = Field(None, ge=1, le=5)


class FlashcardReview(BaseModel):
    """Submit a review result for spaced repetition calculation."""
    quality: int = Field(..., ge=0, le=5)  # 0=complete blackout, 5=perfect recall
