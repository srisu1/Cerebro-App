"""
CEREBRO - Quiz Engine Schemas
Pydantic models for study materials, generated quizzes, questions, scheduling.
"""

from datetime import datetime, date
from decimal import Decimal
from typing import Optional, List
from uuid import UUID
from pydantic import BaseModel, Field



class StudyMaterialCreate(BaseModel):
    subject_id: Optional[UUID] = None
    title: str = Field(..., max_length=200)
    content: str = Field(..., min_length=10)
    source_type: str = Field(default="typed", pattern="^(typed|pasted|pdf_upload|image_upload|session_import)$")
    topics: List[str] = []


class StudyMaterialUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    content: Optional[str] = None
    subject_id: Optional[UUID] = None
    topics: Optional[List[str]] = None


class StudyMaterialResponse(BaseModel):
    id: UUID
    user_id: UUID
    subject_id: Optional[UUID]
    title: str
    content: str
    source_type: str
    topics: List[str]
    word_count: int
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True



class QuizGenerateRequest(BaseModel):
    material_ids: List[UUID] = Field(..., min_length=1)
    subject_id: Optional[UUID] = None
    title: Optional[str] = Field(None, max_length=200)
    question_count: int = Field(default=10, ge=3, le=50)
    question_types: List[str] = Field(default=["mcq", "true_false", "fill_blank"])
    difficulty: Optional[int] = Field(None, ge=1, le=5)  # None = mixed
    time_limit_minutes: Optional[int] = Field(None, ge=1, le=180)
    # Optional: names of topics to focus the generator on. When present, the AI
    # is told to draw questions primarily from these topics (subset of what
    # actually appears on the selected materials).
    topic_filter: Optional[List[str]] = None



class QuizQuestionResponse(BaseModel):
    id: UUID
    question_type: str
    question_text: str
    options: List[str]
    correct_answer: Optional[str] = None  # Hidden during quiz, shown in review
    explanation: Optional[str] = None
    topic: Optional[str]
    difficulty: int
    user_answer: Optional[str]
    is_correct: Optional[bool]
    order_index: int

    class Config:
        from_attributes = True


class QuizQuestionForTaking(BaseModel):
    """Question view during quiz — hides correct answer and explanation."""
    id: UUID
    question_type: str
    question_text: str
    options: List[str]
    topic: Optional[str]
    difficulty: int
    order_index: int
    user_answer: Optional[str]
    is_correct: Optional[bool]

    class Config:
        from_attributes = True


class AnswerSubmit(BaseModel):
    question_id: UUID
    user_answer: str



class GeneratedQuizResponse(BaseModel):
    id: UUID
    user_id: UUID
    subject_id: Optional[UUID]
    title: str
    quiz_type: str
    source: str
    topic_focus: List[str]
    total_questions: int
    time_limit_minutes: Optional[int]
    status: str
    score_achieved: Optional[Decimal]
    max_score: Optional[Decimal]
    correct_count: int
    xp_earned: int
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class GeneratedQuizDetail(GeneratedQuizResponse):
    """Full quiz detail including all questions."""
    questions: List[QuizQuestionResponse] = []


class GeneratedQuizForTaking(BaseModel):
    """Quiz view during taking — questions hide answers."""
    id: UUID
    title: str
    quiz_type: str
    topic_focus: List[str]
    total_questions: int
    time_limit_minutes: Optional[int]
    status: str
    started_at: Optional[datetime]
    questions: List[QuizQuestionForTaking] = []

    class Config:
        from_attributes = True



class QuizScheduleCreate(BaseModel):
    frequency: str = Field(default="weekly", pattern="^(weekly|biweekly|monthly)$")
    day_of_week: int = Field(default=0, ge=0, le=6)
    question_count: int = Field(default=10, ge=5, le=25)
    question_types: List[str] = Field(default=["mcq", "true_false", "fill_blank"])
    enabled: bool = True


class QuizScheduleResponse(BaseModel):
    id: UUID
    frequency: str
    day_of_week: int
    question_count: int
    question_types: List[str]
    enabled: bool
    last_generated_at: Optional[datetime]
    next_due_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True
