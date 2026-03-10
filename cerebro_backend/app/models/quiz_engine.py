import uuid
from datetime import datetime, date
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Text,
    ForeignKey, Date, DECIMAL, ARRAY, CheckConstraint
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base


class StudyMaterial(Base):
    __tablename__ = "study_materials"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id", ondelete="SET NULL"))
    title = Column(String(200), nullable=False)
    content = Column(Text, nullable=False)
    source_type = Column(String(50), default="typed")  # typed, pasted, pdf_upload, image_upload
    topics = Column(ARRAY(String(200)), default=[])
    word_count = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", backref="study_materials")
    subject = relationship("Subject", backref="study_materials")

    def __repr__(self):
        return f"<StudyMaterial {self.title} ({self.word_count} words)>"


class GeneratedQuiz(Base):
    __tablename__ = "generated_quizzes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(UUID(as_uuid=True), ForeignKey("subjects.id", ondelete="SET NULL"))
    title = Column(String(200), nullable=False)
    quiz_type = Column(String(50), default="practice")  # practice, weekly, biweekly, monthly, custom
    source = Column(String(50), default="algorithmic")  # ai, algorithmic, manual
    material_ids = Column(ARRAY(UUID(as_uuid=True)), default=[])
    topic_focus = Column(ARRAY(String(200)), default=[])
    total_questions = Column(Integer, default=0)
    time_limit_minutes = Column(Integer)
    status = Column(String(30), default="pending")  # pending, in_progress, completed, abandoned
    score_achieved = Column(DECIMAL(5, 2))
    max_score = Column(DECIMAL(5, 2))
    correct_count = Column(Integer, default=0)
    xp_earned = Column(Integer, default=0)
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User", backref="generated_quizzes")
    subject = relationship("Subject", backref="generated_quizzes")
    questions = relationship("QuizQuestion", back_populates="quiz",
                             cascade="all, delete-orphan",
                             order_by="QuizQuestion.order_index")

    @property
    def percentage(self):
        if self.max_score and float(str(self.max_score)) > 0:
            return float(str(self.score_achieved or 0)) / float(str(self.max_score)) * 100
        return 0.0

    def __repr__(self):
        return f"<GeneratedQuiz {self.title} ({self.status})>"


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    quiz_id = Column(UUID(as_uuid=True), ForeignKey("generated_quizzes.id", ondelete="CASCADE"), nullable=False)
    question_type = Column(String(30), nullable=False)  # mcq, true_false, fill_blank
    question_text = Column(Text, nullable=False)
    options = Column(ARRAY(String(500)), default=[])
    correct_answer = Column(String(500), nullable=False)
    explanation = Column(Text)
    topic = Column(String(200))
    difficulty = Column(Integer, default=3)  # 1-5
    user_answer = Column(String(500))
    is_correct = Column(Boolean)
    order_index = Column(Integer, default=0)

    __table_args__ = (
        CheckConstraint("difficulty BETWEEN 1 AND 5", name="check_question_difficulty"),
    )

    quiz = relationship("GeneratedQuiz", back_populates="questions")

    def __repr__(self):
        return f"<QuizQuestion {self.question_type}: {self.question_text[:40]}...>"


class QuizSchedule(Base):
    __tablename__ = "quiz_schedules"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    frequency = Column(String(30), default="weekly")  # weekly, biweekly, monthly
    day_of_week = Column(Integer, default=0)  # 0=Monday, 6=Sunday
    question_count = Column(Integer, default=10)
    question_types = Column(ARRAY(String(30)), default=["mcq", "true_false", "fill_blank"])
    enabled = Column(Boolean, default=True)
    last_generated_at = Column(DateTime(timezone=True))
    next_due_at = Column(DateTime(timezone=True))
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow)

    user = relationship("User", backref="quiz_schedule")

    def __repr__(self):
        return f"<QuizSchedule {self.frequency} ({'enabled' if self.enabled else 'disabled'})>"
