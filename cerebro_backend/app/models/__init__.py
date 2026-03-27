"""
CEREBRO Backend - Database Models
All SQLAlchemy models for the application.
"""

from app.models.user import User
from app.models.study import Subject, StudySession, Quiz, Flashcard, FlashcardDeck, Resource, ResourceRecommendation
from app.models.quiz_engine import StudyMaterial, GeneratedQuiz, QuizQuestion, QuizSchedule
from app.models.topic import (
    Topic,
    material_topics, session_topics, deck_topics,
    flashcard_topics, quiz_topics, generated_quiz_topics,
    normalize_topic_name,
)
from app.models.health import SleepLog, Medication, MedicationLog, MoodDefinition, MoodEntry
from app.models.daily import PasswordEntry, HabitEntry, ScheduleEntry
from app.models.gamification import UserAvatar, Achievement, UserAchievement, XPTransaction
from app.models.smart_schedule import SmartScheduleConfig

__all__ = [
    "User",
    "Subject", "StudySession", "Quiz", "Flashcard", "FlashcardDeck",
    "Resource", "ResourceRecommendation",
    "StudyMaterial", "GeneratedQuiz", "QuizQuestion", "QuizSchedule",
    "Topic",
    "material_topics", "session_topics", "deck_topics",
    "flashcard_topics", "quiz_topics", "generated_quiz_topics",
    "normalize_topic_name",
    "SleepLog", "Medication", "MedicationLog", "MoodDefinition", "MoodEntry",
    "PasswordEntry", "HabitEntry", "ScheduleEntry",
    "UserAvatar", "Achievement", "UserAchievement", "XPTransaction",
    "SmartScheduleConfig",
]
