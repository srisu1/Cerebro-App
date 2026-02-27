from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from uuid import UUID
from datetime import date, datetime
from decimal import Decimal
from collections import Counter

from app.database import get_db
from app.models.user import User
from app.models.health import (
    SleepLog, Medication, MedicationLog, MoodDefinition, MoodEntry,
    SymptomLog, WaterLog,
)
from app.schemas.health import (
    SleepLogCreate, SleepLogResponse,
    MedicationCreate, MedicationResponse, MedicationUpdate, AdherenceStatsResponse,
    MedicationLogCreate, MedicationLogResponse,
    MoodEntryCreate, MoodEntryResponse, MoodDefinitionResponse,
    SymptomLogCreate, SymptomLogResponse, SymptomPatternsResponse,
    WaterLogCreate, WaterLogResponse,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/health", tags=["health"])


# --- sleep ---

@router.post("/sleep", response_model=SleepLogResponse, status_code=status.HTTP_201_CREATED)
def log_sleep(
    data: SleepLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    delta = data.wake_time - data.bedtime
    total_hours = Decimal(str(round(delta.total_seconds() / 3600, 2)))

    sleep_log = SleepLog(
        user_id=current_user.id,
        total_hours=total_hours,
        **data.model_dump(),
    )
    db.add(sleep_log)

    # xp for logging sleep
    current_user.total_xp += 10
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(sleep_log)
    return sleep_log


@router.get("/sleep", response_model=List[SleepLogResponse])
def get_sleep_logs(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    limit: int = Query(default=30, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(SleepLog).filter(SleepLog.user_id == current_user.id)
    if start_date:
        query = query.filter(SleepLog.date >= start_date)
    if end_date:
        query = query.filter(SleepLog.date <= end_date)
    return query.order_by(SleepLog.date.desc()).limit(limit).all()


# --- medications ---

@router.post("/medications", response_model=MedicationResponse, status_code=status.HTTP_201_CREATED)
def create_medication(
    data: MedicationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    med = Medication(user_id=current_user.id, **data.model_dump())
    db.add(med)
    db.commit()
    db.refresh(med)
    return med


@router.get("/medications", response_model=List[MedicationResponse])
def list_medications(
    active_only: bool = Query(default=True),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Medication).filter(Medication.user_id == current_user.id)
    if active_only:
        query = query.filter(Medication.is_active == True)
    return query.all()


@router.put("/medications/{med_id}", response_model=MedicationResponse)
def update_medication(
    med_id: UUID,
    data: MedicationUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    med = db.query(Medication).filter(
        Medication.id == med_id, Medication.user_id == current_user.id
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(med, key, value)

    db.commit()
    db.refresh(med)
    return med


@router.delete("/medications/{med_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_medication(
    med_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    med = db.query(Medication).filter(
        Medication.id == med_id, Medication.user_id == current_user.id
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    med.is_active = False
    db.commit()


@router.post("/medications/log", response_model=MedicationLogResponse, status_code=status.HTTP_201_CREATED)
def log_medication(
    data: MedicationLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    log = MedicationLog(user_id=current_user.id, **data.model_dump())
    db.add(log)

    if data.status == "taken":
        current_user.total_xp += 5

    db.commit()
    db.refresh(log)
    return log


@router.get("/medications/adherence", response_model=List[AdherenceStatsResponse])
def get_adherence_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    meds = db.query(Medication).filter(
        Medication.user_id == current_user.id, Medication.is_active == True
    ).all()

    results = []
    for med in meds:
        logs = db.query(MedicationLog).filter(MedicationLog.medication_id == med.id).all()
        taken = sum(1 for l in logs if l.status == "taken")
        skipped = sum(1 for l in logs if l.status == "skipped")
        delayed = sum(1 for l in logs if l.status == "delayed")
        total = len(logs)
        side_fx = sum(1 for l in logs if l.side_effects)

        # current streak (consecutive taken from most recent)
        streak = 0
        sorted_logs = sorted(logs, key=lambda l: l.created_at, reverse=True)
        for l in sorted_logs:
            if l.status == "taken":
                streak += 1
            else:
                break

        results.append(AdherenceStatsResponse(
            medication_id=med.id,
            medication_name=med.name,
            total_logs=total,
            taken_count=taken,
            skipped_count=skipped,
            delayed_count=delayed,
            adherence_pct=round((taken / total) * 100, 1) if total > 0 else 0.0,
            current_streak=streak,
            side_effects_reported=side_fx,
        ))
    return results


@router.get("/medications/logs", response_model=List[MedicationLogResponse])
def get_all_medication_logs(
    limit: int = Query(default=30, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(MedicationLog)
        .filter(MedicationLog.user_id == current_user.id)
        .order_by(MedicationLog.created_at.desc())
        .limit(limit)
        .all()
    )


@router.get("/medications/{med_id}/logs", response_model=List[MedicationLogResponse])
def get_medication_logs(
    med_id: UUID,
    limit: int = Query(default=30, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(MedicationLog)
        .filter(MedicationLog.medication_id == med_id, MedicationLog.user_id == current_user.id)
        .order_by(MedicationLog.created_at.desc())
        .limit(limit)
        .all()
    )


# --- mood ---

@router.get("/moods/definitions", response_model=List[MoodDefinitionResponse])
def get_mood_definitions(db: Session = Depends(get_db)):
    return db.query(MoodDefinition).order_by(MoodDefinition.display_order).all()


@router.post("/moods", response_model=MoodEntryResponse, status_code=status.HTTP_201_CREATED)
def log_mood(
    data: MoodEntryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    mood = db.query(MoodDefinition).filter(MoodDefinition.id == data.mood_id).first()
    if not mood:
        raise HTTPException(status_code=404, detail="Mood type not found")

    entry = MoodEntry(user_id=current_user.id, **data.model_dump())
    db.add(entry)

    current_user.total_xp += 5

    db.commit()
    db.refresh(entry)

    response = MoodEntryResponse.model_validate(entry)
    response.mood_name = mood.name
    return response


@router.get("/moods", response_model=List[MoodEntryResponse])
def get_mood_entries(
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    limit: int = Query(default=30, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(MoodEntry).filter(MoodEntry.user_id == current_user.id)
    if start_date:
        query = query.filter(MoodEntry.timestamp >= start_date)
    if end_date:
        query = query.filter(MoodEntry.timestamp <= end_date)
    return query.order_by(MoodEntry.timestamp.desc()).limit(limit).all()


# --- symptoms ---

@router.post("/symptoms", response_model=SymptomLogResponse, status_code=status.HTTP_201_CREATED)
def log_symptom(
    data: SymptomLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    symptom = SymptomLog(user_id=current_user.id, **data.model_dump())
    db.add(symptom)

    current_user.total_xp += 5
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(symptom)
    return symptom


@router.get("/symptoms", response_model=List[SymptomLogResponse])
def get_symptom_logs(
    symptom_type: Optional[str] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    limit: int = Query(default=30, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(SymptomLog).filter(SymptomLog.user_id == current_user.id)
    if symptom_type:
        query = query.filter(SymptomLog.symptom_type == symptom_type)
    if start_date:
        query = query.filter(SymptomLog.recorded_at >= datetime.combine(start_date, datetime.min.time()))
    if end_date:
        query = query.filter(SymptomLog.recorded_at <= datetime.combine(end_date, datetime.max.time()))
    return query.order_by(SymptomLog.recorded_at.desc()).limit(limit).all()


@router.get("/symptoms/patterns", response_model=SymptomPatternsResponse)
def get_symptom_patterns(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    logs = (
        db.query(SymptomLog)
        .filter(SymptomLog.user_id == current_user.id)
        .order_by(SymptomLog.recorded_at.desc())
        .limit(100)
        .all()
    )

    if not logs:
        return SymptomPatternsResponse(total_logged=0)

    type_counter = Counter(l.symptom_type for l in logs)
    most_common_type, most_common_count = type_counter.most_common(1)[0]

    avg_intensity = round(sum(l.intensity for l in logs) / len(logs), 1)

    trigger_counter: Counter = Counter()
    for l in logs:
        if l.triggers:
            trigger_counter.update(l.triggers)
    top_triggers = [
        {"trigger": t, "count": c, "pct": round(c / len(logs) * 100, 1)}
        for t, c in trigger_counter.most_common(5)
    ]

    relief_counter: Counter = Counter()
    for l in logs:
        if l.relief_methods:
            relief_counter.update(l.relief_methods)
    top_relief = [
        {"method": m, "count": c}
        for m, c in relief_counter.most_common(5)
    ]

    # check if symptom times cluster around certain hours
    correlations = []
    hour_counter = Counter(l.recorded_at.hour for l in logs if l.recorded_at)
    if hour_counter:
        peak_hour, peak_count = hour_counter.most_common(1)[0]
        pct = round(peak_count / len(logs) * 100)
        if pct > 30:
            period = "morning" if peak_hour < 12 else "afternoon" if peak_hour < 17 else "evening"
            correlations.append(f"Most symptoms occur in the {period} ({pct}% of cases)")

    if trigger_counter:
        for trigger, count in trigger_counter.most_common(3):
            related = [l for l in logs if trigger in (l.triggers or [])]
            if related:
                avg_int = sum(l.intensity for l in related) / len(related)
                if avg_int > 6:
                    correlations.append(
                        f"'{trigger}' trigger linked to high intensity (avg {avg_int:.1f}/10)"
                    )

    return SymptomPatternsResponse(
        total_logged=len(logs),
        most_common_type=most_common_type,
        most_common_count=most_common_count,
        avg_intensity=avg_intensity,
        top_triggers=top_triggers,
        top_relief=top_relief,
        correlations=correlations,
    )


# --- water ---

@router.post("/water", response_model=WaterLogResponse, status_code=status.HTTP_201_CREATED)
def log_water(
    data: WaterLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()

    existing = db.query(WaterLog).filter(
        WaterLog.user_id == current_user.id, WaterLog.date == today
    ).first()

    if existing:
        old_glasses = existing.glasses
        existing.glasses = data.glasses
        if data.goal is not None:
            existing.goal = data.goal
        existing.updated_at = datetime.utcnow()

        new_glasses = data.glasses - old_glasses
        if new_glasses > 0:
            current_user.total_xp += new_glasses * 2
            current_user.level = (current_user.total_xp // 500) + 1

        db.commit()
        db.refresh(existing)
        return existing
    else:
        water = WaterLog(
            user_id=current_user.id,
            date=today,
            glasses=data.glasses,
            goal=data.goal or 8,
        )
        db.add(water)

        if data.glasses > 0:
            current_user.total_xp += data.glasses * 2
            current_user.level = (current_user.total_xp // 500) + 1

        db.commit()
        db.refresh(water)
        return water


@router.get("/water/today", response_model=Optional[WaterLogResponse])
def get_today_water(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    entry = db.query(WaterLog).filter(
        WaterLog.user_id == current_user.id, WaterLog.date == today
    ).first()
    return entry


@router.get("/water", response_model=List[WaterLogResponse])
def get_water_history(
    days: int = Query(default=7, le=90),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(WaterLog)
        .filter(WaterLog.user_id == current_user.id)
        .order_by(WaterLog.date.desc())
        .limit(days)
        .all()
    )
