from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date
from uuid import UUID
from decimal import Decimal


# subject
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

    class Config:
        from_attributes = True


class SubjectUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    code: Optional[str] = Field(None, max_length=50)
    color: Optional[str] = Field(None, pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: Optional[str] = Field(None, max_length=50)
    target_proficiency: Optional[Decimal] = Field(None, ge=0, le=100)


# study session
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

    class Config:
        from_attributes = True


class StudySessionUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    notes: Optional[str] = None
    topics_covered: Optional[List[str]] = None
    focus_score: Optional[int] = Field(None, ge=1, le=100)


# quiz
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

    class Config:
        from_attributes = True


# flashcard deck
class FlashcardDeckCreate(BaseModel):
    subject_id: Optional[UUID] = None
    name: str = Field(..., min_length=1, max_length=200)
    description: Optional[str] = ""
    color: str = Field(default="#A8D5A3", pattern=r"^#[0-9A-Fa-f]{6}$")
    icon: str = Field(default="layers", max_length=50)


class FlashcardDeckUpdate(BaseModel):
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

    class Config:
        from_attributes = True


# flashcard
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

    class Config:
        from_attributes = True


class FlashcardReview(BaseModel):
    quality: int = Field(..., ge=0, le=5)  # 0=complete blackout, 5=perfect recall
