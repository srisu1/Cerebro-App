"""
CEREBRO - User Schemas
Pydantic models for request/response validation.
"""

from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from datetime import datetime, time
from uuid import UUID


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    display_name: str = Field(..., min_length=2, max_length=100)
    university: Optional[str] = None
    course: Optional[str] = None
    year_of_study: Optional[int] = Field(None, ge=1, le=7)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str


class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    user_id: Optional[UUID] = None


class UserResponse(BaseModel):
    id: UUID
    email: str
    display_name: str
    institution_type: Optional[str] = None
    university: Optional[str] = None
    course: Optional[str] = None
    year_of_study: Optional[int] = None
    degree_level: Optional[str] = None
    affiliation: Optional[str] = None
    daily_study_hours: Optional[float] = None
    study_goals: List[str] = []
    bedtime: Optional[time] = None
    wake_time: Optional[time] = None
    sleep_hours_target: Optional[float] = None
    initial_mood: Optional[str] = None
    initial_habits: List[str] = []
    medical_conditions: List[str] = []
    allergies: List[str] = []
    total_xp: int
    level: int
    streak_days: int
    coins: int
    auth_provider: Optional[str] = "email"
    has_password: bool = True
    # Notification prefs — defaults are sensible for existing rows that
    # pre-date the columns (auto-migration backfills TRUE).
    notifications_enabled: bool = True
    daily_reminders_enabled: bool = True
    created_at: datetime

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=2, max_length=100)
    institution_type: Optional[str] = None
    university: Optional[str] = None
    course: Optional[str] = None
    year_of_study: Optional[int] = Field(None, ge=1, le=12)
    bio: Optional[str] = None
    # Wizard-derived academic context
    degree_level: Optional[str] = Field(
        None, pattern=r"^(undergraduate|masters|phd)$")
    affiliation: Optional[str] = Field(None, max_length=300)
    # Study preferences
    daily_study_hours: Optional[float] = Field(None, ge=0, le=24)
    study_goals: Optional[List[str]] = None
    # Sleep preferences
    bedtime: Optional[time] = None
    wake_time: Optional[time] = None
    sleep_hours_target: Optional[float] = Field(None, ge=0, le=24)
    # Wellbeing seed
    initial_mood: Optional[str] = Field(None, max_length=50)
    initial_habits: Optional[List[str]] = None
    # Medical context (wizard + settings)
    medical_conditions: Optional[List[str]] = None
    allergies: Optional[List[str]] = None
    # Notification prefs — surfaced in Profile → Settings toggles.
    notifications_enabled: Optional[bool] = None
    daily_reminders_enabled: Optional[bool] = None
