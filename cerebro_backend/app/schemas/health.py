from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date, time
from uuid import UUID
from decimal import Decimal


# sleep
class SleepLogCreate(BaseModel):
    date: date
    bedtime: datetime
    wake_time: datetime
    quality_rating: Optional[int] = Field(None, ge=1, le=5)
    notes: Optional[str] = None
    source: str = Field(default="manual", pattern=r"^(manual|google_fit)$")


class SleepLogResponse(BaseModel):
    id: UUID
    date: date
    bedtime: datetime
    wake_time: datetime
    total_hours: Optional[Decimal]
    quality_rating: Optional[int]
    notes: Optional[str]
    source: str
    created_at: datetime

    class Config:
        from_attributes = True


# medication
class MedicationCreate(BaseModel):
    name: str = Field(..., max_length=100)
    dosage: str = Field(..., max_length=100)
    frequency: str = Field(..., pattern=r"^(daily|weekly|as_needed)$")
    times_of_day: List[time] = []
    days_of_week: List[int] = [1, 2, 3, 4, 5, 6, 7]
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    reminder_enabled: bool = True


class MedicationResponse(BaseModel):
    id: UUID
    name: str
    dosage: str
    frequency: str
    times_of_day: List[time]
    days_of_week: List[int]
    start_date: Optional[date]
    end_date: Optional[date]
    reminder_enabled: bool
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class MedicationUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=100)
    dosage: Optional[str] = Field(None, max_length=100)
    frequency: Optional[str] = Field(None, pattern=r"^(daily|weekly|as_needed)$")
    times_of_day: Optional[List[time]] = None
    reminder_enabled: Optional[bool] = None
    is_active: Optional[bool] = None


# medication log
class MedicationLogCreate(BaseModel):
    medication_id: UUID
    scheduled_time: datetime
    taken_at: Optional[datetime] = None
    status: str = Field(..., pattern=r"^(taken|skipped|delayed)$")
    side_effects: Optional[str] = None


class MedicationLogResponse(BaseModel):
    id: UUID
    medication_id: UUID
    scheduled_time: datetime
    taken_at: Optional[datetime]
    status: str
    side_effects: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class AdherenceStatsResponse(BaseModel):
    medication_id: UUID
    medication_name: str
    total_logs: int
    taken_count: int
    skipped_count: int
    delayed_count: int
    adherence_pct: float
    current_streak: int
    side_effects_reported: int

    class Config:
        from_attributes = True


# mood
class MoodEntryCreate(BaseModel):
    mood_id: UUID
    note: Optional[str] = None
    energy_level: Optional[int] = Field(None, ge=1, le=5)
    context_tags: List[str] = []


class MoodEntryResponse(BaseModel):
    id: UUID
    mood_id: UUID
    mood_name: Optional[str] = None
    timestamp: datetime
    note: Optional[str]
    energy_level: Optional[int]
    context_tags: List[str]
    created_at: datetime

    class Config:
        from_attributes = True


class MoodDefinitionResponse(BaseModel):
    id: UUID
    name: str
    display_order: Optional[int]
    eyes_asset_path: str
    mouth_asset_path: str
    nose_asset_path: Optional[str]
    color: Optional[str]

    class Config:
        from_attributes = True


# symptom
class SymptomLogCreate(BaseModel):
    symptom_type: str = Field(..., max_length=50)
    intensity: int = Field(..., ge=1, le=10)
    duration_minutes: Optional[int] = Field(None, ge=0)
    triggers: List[str] = []
    relief_methods: List[str] = []
    notes: Optional[str] = None


class SymptomLogResponse(BaseModel):
    id: UUID
    symptom_type: str
    intensity: int
    duration_minutes: Optional[int]
    triggers: List[str]
    relief_methods: List[str]
    notes: Optional[str]
    recorded_at: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class SymptomPatternsResponse(BaseModel):
    total_logged: int
    most_common_type: Optional[str]
    most_common_count: int = 0
    avg_intensity: float = 0.0
    top_triggers: List[dict] = []
    top_relief: List[dict] = []
    correlations: List[str] = []


# water
class WaterLogCreate(BaseModel):
    glasses: int = Field(..., ge=0, le=20)
    goal: Optional[int] = Field(None, ge=1, le=20)


class WaterLogResponse(BaseModel):
    id: UUID
    date: date
    glasses: int
    goal: int
    updated_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True
