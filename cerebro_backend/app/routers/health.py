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
    HealthInsightsResponse, HealthInsight, WeeklySummary,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/health", tags=["health"])


#  SLEEP TRACKING

@router.post("/sleep", response_model=SleepLogResponse, status_code=status.HTTP_201_CREATED)
def log_sleep(
    data: SleepLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Calculate total hours — handle overnight sleep (bedtime > wake_time)
    delta = data.wake_time - data.bedtime
    if delta.total_seconds() < 0:
        # Wake time is next day (e.g., bed 23:00, wake 07:00)
        from datetime import timedelta
        delta = delta + timedelta(days=1)
    total_secs = min(delta.total_seconds(), 86400)  # Cap at 24h
    total_hours = Decimal(str(round(total_secs / 3600, 2)))

    sleep_log = SleepLog(
        user_id=current_user.id,
        total_hours=total_hours,
        **data.model_dump(),
    )
    db.add(sleep_log)

    # XP for logging sleep
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


#  MEDICATIONS

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


@router.post("/medications/log", response_model=MedicationLogResponse, status_code=status.HTTP_201_CREATED)
def log_medication(
    data: MedicationLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    log = MedicationLog(user_id=current_user.id, **data.model_dump())
    db.add(log)

    # XP for adherence
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

        # Compute current streak (consecutive 'taken' from most recent)
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


#  MOOD TRACKING

@router.get("/moods/definitions", response_model=List[MoodDefinitionResponse])
def get_mood_definitions(db: Session = Depends(get_db)):
    return db.query(MoodDefinition).order_by(MoodDefinition.display_order).all()


@router.post("/moods", response_model=MoodEntryResponse, status_code=status.HTTP_201_CREATED)
def log_mood(
    data: MoodEntryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Resolve mood — accept either UUID id or string name
    mood = None
    if data.mood_id:
        mood = db.query(MoodDefinition).filter(MoodDefinition.id == data.mood_id).first()
    elif data.mood_type:
        mood = db.query(MoodDefinition).filter(
            func.lower(MoodDefinition.name) == data.mood_type.lower()
        ).first()
    if not mood:
        raise HTTPException(status_code=404, detail="Mood type not found")

    # Build entry dict, ensuring mood_id is set
    entry_data = data.model_dump(exclude={'mood_type'})
    entry_data['mood_id'] = mood.id
    entry = MoodEntry(user_id=current_user.id, **entry_data)
    db.add(entry)

    # XP for mood logging
    current_user.total_xp += 5

    db.commit()
    db.refresh(entry)

    # Add mood name to response
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
    entries = query.order_by(MoodEntry.timestamp.desc()).limit(limit).all()

    # Populate mood_name from MoodDefinition lookup
    mood_defs = {str(md.id): md.name for md in db.query(MoodDefinition).all()}
    results = []
    for entry in entries:
        resp = MoodEntryResponse.model_validate(entry)
        resp.mood_name = mood_defs.get(str(entry.mood_id))
        results.append(resp)
    return results


#  MEDICATION — Extended endpoints

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


#  SYMPTOM TRACKING

@router.post("/symptoms", response_model=SymptomLogResponse, status_code=status.HTTP_201_CREATED)
def log_symptom(
    data: SymptomLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    symptom = SymptomLog(user_id=current_user.id, **data.model_dump())
    db.add(symptom)

    # XP for tracking health
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

    # Most common symptom type
    type_counter = Counter(l.symptom_type for l in logs)
    most_common_type, most_common_count = type_counter.most_common(1)[0]

    # Average intensity
    avg_intensity = round(sum(l.intensity for l in logs) / len(logs), 1)

    # Top triggers
    trigger_counter: Counter = Counter()
    for l in logs:
        if l.triggers:
            trigger_counter.update(l.triggers)
    top_triggers = [
        {"trigger": t, "count": c, "pct": round(c / len(logs) * 100, 1)}
        for t, c in trigger_counter.most_common(5)
    ]

    # Top relief methods
    relief_counter: Counter = Counter()
    for l in logs:
        if l.relief_methods:
            relief_counter.update(l.relief_methods)
    top_relief = [
        {"method": m, "count": c}
        for m, c in relief_counter.most_common(5)
    ]

    # Simple correlations — check if symptom times cluster around certain hours
    correlations = []
    hour_counter = Counter(l.recorded_at.hour for l in logs if l.recorded_at)
    if hour_counter:
        peak_hour, peak_count = hour_counter.most_common(1)[0]
        pct = round(peak_count / len(logs) * 100)
        if pct > 30:
            period = "morning" if peak_hour < 12 else "afternoon" if peak_hour < 17 else "evening"
            correlations.append(f"Most symptoms occur in the {period} ({pct}% of cases)")

    # Check if specific triggers strongly correlate with high intensity
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


#  WATER INTAKE TRACKING

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

        # XP: award 2 XP for each new glass (only for increases)
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

        # XP for first log
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


@router.get("/insights", response_model=HealthInsightsResponse)
def get_health_insights(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import timedelta
    today = date.today()
    week_ago = today - timedelta(days=7)

    insights: List[HealthInsight] = []

    # Sleep (last 7 days)
    sleep_logs = (
        db.query(SleepLog)
        .filter(SleepLog.user_id == current_user.id, SleepLog.date >= week_ago)
        .order_by(SleepLog.date.desc())
        .all()
    )
    # Mood (last 7 days)
    mood_entries = (
        db.query(MoodEntry)
        .filter(MoodEntry.user_id == current_user.id,
                MoodEntry.timestamp >= datetime.combine(week_ago, datetime.min.time()))
        .order_by(MoodEntry.timestamp.desc())
        .all()
    )
    # Medications (active)
    active_meds = (
        db.query(Medication)
        .filter(Medication.user_id == current_user.id, Medication.is_active == True)
        .all()
    )
    # Medication logs (last 7 days)
    med_logs = (
        db.query(MedicationLog)
        .filter(MedicationLog.user_id == current_user.id,
                MedicationLog.created_at >= datetime.combine(week_ago, datetime.min.time()))
        .all()
    )
    # Water (last 7 days)
    water_logs = (
        db.query(WaterLog)
        .filter(WaterLog.user_id == current_user.id, WaterLog.date >= week_ago)
        .all()
    )
    # Symptoms (last 7 days)
    symptom_logs = (
        db.query(SymptomLog)
        .filter(SymptomLog.user_id == current_user.id,
                SymptomLog.recorded_at >= datetime.combine(week_ago, datetime.min.time()))
        .all()
    )

    avg_sleep = 0.0
    if sleep_logs:
        avg_sleep = round(float(sum(float(s.total_hours or 0) for s in sleep_logs)) / len(sleep_logs), 1)

    avg_mood = 0.0
    mood_with_energy = [m for m in mood_entries if m.energy_level]
    if mood_with_energy:
        avg_mood = round(sum(m.energy_level for m in mood_with_energy) / len(mood_with_energy), 1)

    med_adherence = 0.0
    taken_count = sum(1 for l in med_logs if l.status == "taken")
    total_med_logs = len(med_logs)
    if total_med_logs > 0:
        med_adherence = round((taken_count / total_med_logs) * 100, 1)

    water_avg = 0.0
    if water_logs:
        water_avg = round(sum(w.glasses for w in water_logs) / len(water_logs), 1)

    symptom_count = len(symptom_logs)
    days_tracked = len(set(
        [s.date for s in sleep_logs] +
        [m.timestamp.date() for m in mood_entries if m.timestamp] +
        [w.date for w in water_logs]
    ))

    summary = WeeklySummary(
        avg_sleep=avg_sleep,
        avg_mood_score=avg_mood,
        med_adherence_pct=med_adherence,
        water_avg=water_avg,
        symptom_count=symptom_count,
        days_tracked=days_tracked,
    )

    # Each category contributes up to 25 points
    score = 0

    # Sleep score (25 pts): 7-9 hrs = perfect, degrades outside
    if sleep_logs:
        if 7 <= avg_sleep <= 9:
            score += 25
        elif 6 <= avg_sleep < 7 or 9 < avg_sleep <= 10:
            score += 18
        elif 5 <= avg_sleep < 6:
            score += 10
        else:
            score += 5
    # No sleep data = 0 pts

    # Mood score (25 pts): avg energy mapped to 25
    if mood_with_energy:
        score += min(25, int((avg_mood / 5.0) * 25))

    # Medication score (25 pts): adherence %
    if active_meds:
        score += min(25, int(med_adherence * 0.25))
    else:
        score += 25  # No meds needed = perfect

    # Water score (25 pts): avg glasses vs 8 goal
    if water_logs:
        score += min(25, int((water_avg / 8.0) * 25))

    score = max(0, min(100, score))


    # 1. Sleep-mood correlation
    if len(sleep_logs) >= 3 and len(mood_entries) >= 3:
        good_sleep_moods = []
        bad_sleep_moods = []
        for sl in sleep_logs:
            day_moods = [m for m in mood_entries
                        if m.timestamp and m.timestamp.date() == sl.date and m.energy_level]
            if day_moods:
                avg_e = sum(m.energy_level for m in day_moods) / len(day_moods)
                if float(sl.total_hours or 0) >= 7:
                    good_sleep_moods.append(avg_e)
                else:
                    bad_sleep_moods.append(avg_e)
        if good_sleep_moods and bad_sleep_moods:
            good_avg = sum(good_sleep_moods) / len(good_sleep_moods)
            bad_avg = sum(bad_sleep_moods) / len(bad_sleep_moods)
            if good_avg > bad_avg + 0.5:
                insights.append(HealthInsight(
                    type="correlation", icon="bulb",
                    text=f"You feel happier on 7+ hour sleep nights (energy {good_avg:.1f} vs {bad_avg:.1f})",
                    priority=10,
                ))

    # 2. Medication streak
    if active_meds and med_logs:
        sorted_med_logs = sorted(med_logs, key=lambda l: l.created_at, reverse=True)
        streak = 0
        for l in sorted_med_logs:
            if l.status == "taken":
                streak += 1
            else:
                break
        if streak >= 3:
            insights.append(HealthInsight(
                type="streak", icon="fire",
                text=f"{streak}-day medication streak! Keep it up",
                priority=9,
            ))
        elif streak == 0 and total_med_logs > 0:
            insights.append(HealthInsight(
                type="warning", icon="pill",
                text="You've missed your recent medications — try setting a reminder",
                priority=8,
            ))

    # 3. Sleep trend (week over week)
    if len(sleep_logs) >= 3:
        recent_half = sleep_logs[:len(sleep_logs)//2]
        older_half = sleep_logs[len(sleep_logs)//2:]
        if recent_half and older_half:
            recent_avg = sum(float(s.total_hours or 0) for s in recent_half) / len(recent_half)
            older_avg = sum(float(s.total_hours or 0) for s in older_half) / len(older_half)
            diff_pct = ((recent_avg - older_avg) / older_avg * 100) if older_avg > 0 else 0
            if diff_pct > 10:
                insights.append(HealthInsight(
                    type="trend", icon="chart_up",
                    text=f"Your sleep improved {abs(diff_pct):.0f}% recently — nice work!",
                    priority=7,
                ))
            elif diff_pct < -10:
                insights.append(HealthInsight(
                    type="trend", icon="chart_down",
                    text=f"Your sleep dropped {abs(diff_pct):.0f}% — try getting to bed earlier tonight",
                    priority=7,
                ))

    # 4. Water consistency
    if water_logs:
        days_met_goal = sum(1 for w in water_logs if w.glasses >= w.goal)
        if days_met_goal == len(water_logs) and len(water_logs) >= 3:
            insights.append(HealthInsight(
                type="streak", icon="water",
                text=f"Perfect hydration for {len(water_logs)} days straight!",
                priority=8,
            ))
        elif water_avg < 4:
            insights.append(HealthInsight(
                type="tip", icon="water",
                text=f"You're averaging {water_avg:.0f} glasses/day — try keeping a bottle on your desk",
                priority=6,
            ))

    # 5. Symptom patterns
    if symptom_logs:
        type_counter = Counter(s.symptom_type for s in symptom_logs)
        most_common, count = type_counter.most_common(1)[0]
        if count >= 3:
            insights.append(HealthInsight(
                type="warning", icon="heart",
                text=f"You've logged {most_common} {count} times this week — consider talking to a doctor if it persists",
                priority=8,
            ))
        # Check trigger patterns
        trigger_counter: Counter = Counter()
        for s in symptom_logs:
            if s.triggers:
                trigger_counter.update(s.triggers)
        if trigger_counter:
            top_trigger, t_count = trigger_counter.most_common(1)[0]
            if t_count >= 2:
                insights.append(HealthInsight(
                    type="correlation", icon="bulb",
                    text=f"'{top_trigger}' appears as a trigger in {t_count} of your symptoms this week",
                    priority=6,
                ))

    # 6. General tips when data is sparse
    if not sleep_logs:
        insights.append(HealthInsight(
            type="tip", icon="moon",
            text="Log your sleep to unlock personalized insights about your rest patterns",
            priority=3,
        ))
    if not mood_entries:
        insights.append(HealthInsight(
            type="tip", icon="heart",
            text="Check in with your mood — tracking it helps you spot patterns over time",
            priority=3,
        ))

    # Sort by priority descending, limit to top 5
    insights.sort(key=lambda i: i.priority, reverse=True)
    insights = insights[:5]

    return HealthInsightsResponse(
        wellness_score=score,
        insights=insights,
        weekly_summary=summary,
    )
