from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, date, timedelta, timezone
from collections import defaultdict, Counter
from typing import List, Dict, Any, Optional, Tuple
import random
import math

from app.database import get_db
from app.models.user import User
from app.models.study import StudySession
from app.models.health import (
    SleepLog,
    MoodEntry,
    MoodDefinition,
    WaterLog,
    SymptomLog,
    Medication,
    MedicationLog,
)
from app.models.daily import HabitEntry, HabitCompletion
from app.utils.auth import get_current_user

router = APIRouter(prefix="/insights", tags=["insights"])


#  SHARED HELPERS

MOOD_SCORES = {
    "happy": 5, "excited": 5, "grateful": 4, "calm": 4,
    "focused": 3, "playful": 3,
    "tired": 2, "sleepy": 2, "anxious": 2,
    "sad": 1, "angry": 1,
}


def _safe_mean(values: list) -> float:
    return sum(values) / len(values) if values else 0.0


def _aware(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _empty_day():
    return {
        "sleep_hours": None, "sleep_quality": None,
        "bedtime_hour": None,       # 0..30 (>24 = after midnight, helps rank late)
        "wake_hour": None,          # 0..24 (morning wake)
        "mood": None, "mood_score": 0,
        "study_minutes": 0, "focus_avg": 0, "focus_scores": [],
        "session_hours": [],        # list of (start_hour, duration_min, focus)
        "longest_session_min": 0,
        "habits_done": 0, "habits_total": 0,
        "water_ml": 0,
        "symptom_count": 0,
        "symptom_intensity": 0,
        "med_scheduled": 0,
        "med_taken": 0,
    }


#  SYNTHETIC AUGMENTATION
#  When the user has < MIN_REAL_DAYS of real data, we
#  blend in plausible synthetic days so the dashboard
#  still looks alive. The RNG is seeded from user.id so
#  the same user always sees the same "demo" pattern.

MIN_REAL_DAYS = 4   # below this, we augment


def _real_days(day_data: Dict[date, Dict[str, Any]]) -> int:
    n = 0
    for dd in day_data.values():
        if (dd["sleep_hours"] is not None
            or (dd["mood_score"] or 0) > 0
            or (dd["study_minutes"] or 0) > 0
            or (dd["habits_done"] or 0) > 0
            or (dd.get("symptom_count") or 0) > 0
            or (dd.get("med_scheduled") or 0) > 0
            or (dd.get("water_ml") or 0) > 0):
            n += 1
    return n


def _augment_with_synthetic(
    day_data: Dict[date, Dict[str, Any]],
    user: User,
    today: date,
    days_back: int = 21,
):
    seed_int = int(str(user.id).replace("-", "")[:8], 16)
    rng = random.Random(seed_int)
    synth_dates: List[str] = []

    # Generate a baseline mood phase + sleep phase + study schedule
    # so the synthetic data has internal correlation (which makes the
    # demo charts and pattern detection light up nicely).
    mood_phase = rng.uniform(0, math.pi * 2)
    sleep_phase = rng.uniform(0, math.pi * 2)
    base_sleep = rng.uniform(6.8, 7.6)
    base_focus = rng.uniform(58, 72)
    base_study_per_day = rng.uniform(28, 55)   # avg minutes
    weekly_skip = rng.choice([5, 6])           # which weekday user "rests"
    avg_habits_total = max(1, rng.randint(2, 4))

    for i in range(days_back):
        d = today - timedelta(days=days_back - 1 - i)
        existing = day_data.get(d)
        is_empty = (
            existing is None or (
                existing["sleep_hours"] is None
                and (existing["mood_score"] or 0) == 0
                and (existing["study_minutes"] or 0) == 0
                and (existing["habits_done"] or 0) == 0
            )
        )
        if not is_empty:
            continue

        # Smooth daily wave for sleep / mood with weekly seasonality
        t = i
        sleep_h = base_sleep + 0.9 * math.sin((t / 6.0) + sleep_phase) \
                  + rng.uniform(-0.4, 0.4)
        sleep_h = max(4.5, min(9.5, sleep_h))

        # Mood loosely follows sleep with a 1-day lag, plus its own wave
        mood_drive = 3.2 + 0.55 * math.sin((t / 5.5) + mood_phase) \
                     + 0.4 * (sleep_h - 7.0)
        mood_score = max(1, min(5, round(mood_drive + rng.uniform(-0.5, 0.5))))

        # Study minutes: weekday-leaning, mood-amplified, occasional zero
        weekday = d.weekday()
        is_rest = (weekday == weekly_skip)
        study_min = 0
        focus_score = 0
        if not is_rest and rng.random() > 0.18:
            mood_boost = 1.0 + 0.18 * (mood_score - 3)   # +/- ~36%
            study_min = int(max(0, base_study_per_day * mood_boost
                                * rng.uniform(0.55, 1.55)))
            if study_min < 8:
                study_min = 0
            else:
                # Focus tracks sleep mostly + small mood lift
                focus_score = int(max(20, min(100,
                    base_focus + 4.0 * (sleep_h - 7.0) + 2.0 * (mood_score - 3)
                    + rng.uniform(-8, 8))))

        habits_done = rng.randint(
            0,
            avg_habits_total if mood_score >= 3 else max(1, avg_habits_total - 1),
        )

        new = _empty_day()
        new["sleep_hours"] = round(sleep_h, 1)
        new["sleep_quality"] = max(1, min(5, round(sleep_h - 3)))
        new["mood_score"] = mood_score
        # Map score back to a name so the dominant-mood logic still works
        name_for_score = {
            5: "happy", 4: "calm", 3: "focused", 2: "tired", 1: "sad"
        }
        new["mood"] = name_for_score.get(mood_score, "calm")
        new["study_minutes"] = study_min
        if focus_score:
            new["focus_scores"] = [focus_score]
            new["focus_avg"] = focus_score
        new["habits_done"] = habits_done
        new["habits_total"] = avg_habits_total
        new["water_ml"] = rng.choice([1000, 1250, 1500, 1750, 2000])
        new["_synthetic"] = True
        day_data[d] = new
        synth_dates.append(d.isoformat())

    return synth_dates


#  MAIN INSIGHTS ENDPOINT

@router.get("/dashboard")
def get_insights_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = current_user.id
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)

    sleep_logs = (
        db.query(SleepLog)
        .filter(SleepLog.user_id == user_id, SleepLog.date >= month_ago)
        .order_by(SleepLog.date)
        .all()
    )
    # MoodEntry has TWO datetime fields: `timestamp` (when the mood was
    # *felt*) and `created_at` (when the row was inserted). Seed scripts
    # backfill history with real timestamps but created_at=now(), so
    # bucketing by created_at collapses all history into "today". Always
    # use `timestamp` for both the filter and the date bucket.
    mood_entries = (
        db.query(MoodEntry)
        .filter(MoodEntry.user_id == user_id,
                MoodEntry.timestamp >= _aware(datetime.combine(month_ago, datetime.min.time())))
        .order_by(MoodEntry.timestamp)
        .all()
    )
    mood_defs = db.query(MoodDefinition).all()
    mood_id_to_name = {str(md.id): md.name.lower() for md in mood_defs}
    study_sessions = (
        db.query(StudySession)
        .filter(StudySession.user_id == user_id,
                StudySession.start_time >= _aware(datetime.combine(month_ago, datetime.min.time())))
        .all()
    )
    habit_completions = (
        db.query(HabitCompletion)
        .filter(HabitCompletion.user_id == user_id,
                HabitCompletion.date >= month_ago)
        .all()
    )
    water_logs = (
        db.query(WaterLog)
        .filter(WaterLog.user_id == user_id, WaterLog.date >= month_ago)
        .all()
    )
    symptom_logs = (
        db.query(SymptomLog)
        .filter(SymptomLog.user_id == user_id,
                SymptomLog.recorded_at >= _aware(datetime.combine(month_ago, datetime.min.time())))
        .all()
    )
    medication_logs = (
        db.query(MedicationLog)
        .filter(MedicationLog.user_id == user_id,
                MedicationLog.scheduled_time >= _aware(datetime.combine(month_ago, datetime.min.time())))
        .all()
    )

    day_data: Dict[date, Dict[str, Any]] = defaultdict(_empty_day)

    for sl in sleep_logs:
        d = sl.date
        day_data[d]["sleep_hours"] = float(sl.total_hours) if sl.total_hours else None
        day_data[d]["sleep_quality"] = sl.quality_rating
        # Bedtime hour — encode late bedtimes as 24+ so a linear correlation
        # captures "later = worse quality" in a sensible way.
        if sl.bedtime:
            bt = _aware(sl.bedtime)
            # If bedtime is between midnight and 6am, treat as "previous day
            # late" — add 24 so ordering remains monotonic relative to evening.
            bh = bt.hour + bt.minute / 60.0
            if bh < 6:
                bh += 24
            day_data[d]["bedtime_hour"] = round(bh, 2)
        if sl.wake_time:
            wt = _aware(sl.wake_time)
            day_data[d]["wake_hour"] = round(wt.hour + wt.minute / 60.0, 2)

    for me in mood_entries:
        # Bucket by `timestamp` — the actual event date — not `created_at`.
        # Seeded/backfilled moods have created_at=now() but timestamp=real.
        bucket_dt = me.timestamp or me.created_at
        d = bucket_dt.date() if bucket_dt else today
        mood_name = mood_id_to_name.get(str(me.mood_id), "calm")
        day_data[d]["mood"] = mood_name
        day_data[d]["mood_score"] = MOOD_SCORES.get(mood_name, 3)

    for ss in study_sessions:
        if ss.start_time:
            d = ss.start_time.date()
            dur = ss.duration_minutes or 0
            day_data[d]["study_minutes"] += dur
            if ss.focus_score and ss.focus_score > 0:
                day_data[d]["focus_scores"].append(ss.focus_score)
            # Hour-level bookkeeping for peak-window detection
            day_data[d]["session_hours"].append(
                (ss.start_time.hour, dur, ss.focus_score or 0)
            )
            if dur > day_data[d]["longest_session_min"]:
                day_data[d]["longest_session_min"] = dur

    for sy in symptom_logs:
        if sy.recorded_at:
            d = sy.recorded_at.date()
            day_data[d]["symptom_count"] += 1
            day_data[d]["symptom_intensity"] += (sy.intensity or 0)

    for ml in medication_logs:
        if ml.scheduled_time:
            d = ml.scheduled_time.date()
            day_data[d]["med_scheduled"] += 1
            if ml.status == "taken":
                day_data[d]["med_taken"] += 1

    active_habits = (
        db.query(HabitEntry)
        .filter(HabitEntry.user_id == user_id, HabitEntry.is_active == True)
        .count()
    )
    habit_by_date: Dict[date, int] = defaultdict(int)
    for hc in habit_completions:
        habit_by_date[hc.date] += 1
    for d in day_data:
        day_data[d]["habits_done"] = habit_by_date.get(d, 0)
        day_data[d]["habits_total"] = active_habits

    for wl in water_logs:
        day_data[wl.date]["water_ml"] += (wl.glasses or 0) * 250

    for d in day_data:
        scores = day_data[d]["focus_scores"]
        day_data[d]["focus_avg"] = _safe_mean(scores) if scores else 0

    real_n = _real_days(day_data)
    is_synthetic = real_n < MIN_REAL_DAYS
    synth_dates: List[str] = []
    if is_synthetic:
        synth_dates = _augment_with_synthetic(day_data, current_user, today)

    wellness = _compute_wellness_score(day_data, week_ago, today, current_user)
    correlations = _compute_correlations(day_data)
    patterns = _detect_patterns(day_data, sleep_logs, mood_entries, study_sessions)
    # Condition-aware layer — derived from the wizard-collected
    # medical_conditions field. Feeds both the Plan tab and the
    # client-side "aware" banners in Health.
    condition_ctx = _build_condition_context(current_user, day_data, symptom_logs)
    recommendations = _generate_recommendations(
        wellness, correlations, patterns, day_data, current_user
    )
    # Prepend condition-specific recs so users see their own
    # situation-first guidance before the generic cards.
    cond_recs = _condition_recommendations(condition_ctx)
    if cond_recs:
        recommendations = (cond_recs + recommendations)[:10]
    headline = _build_headline(
        wellness, correlations, patterns, day_data, today, is_synthetic
    )

    weekly = []
    for i in range(7):
        d = week_ago + timedelta(days=i + 1)   # ends on today inclusive
        dd = day_data.get(d, _empty_day())
        weekly.append({
            "date": d.isoformat(),
            "day": d.strftime("%a"),
            "sleep_hours": dd.get("sleep_hours"),
            "mood": dd.get("mood"),
            "mood_score": dd.get("mood_score", 0),
            "study_minutes": dd.get("study_minutes", 0),
            "focus_avg": round(dd.get("focus_avg", 0)),
            "habits_done": dd.get("habits_done", 0),
            "habits_total": dd.get("habits_total", 0),
            "water_ml": dd.get("water_ml", 0),
        })

    metric_streams_14 = _build_metric_streams(day_data, today, days=14)

    wellness_history_14 = _build_wellness_history(day_data, today, days=14)

    rhythms = _compute_rhythms(day_data, study_sessions, mood_entries, today,
                                synthetic=is_synthetic, user=current_user)

    recent_days = [d for d in day_data if d >= week_ago]
    study_summary = {
        "total_minutes_week": sum(day_data[d]["study_minutes"] for d in recent_days),
        "avg_focus": round(_safe_mean(
            [day_data[d]["focus_avg"] for d in recent_days
             if day_data[d]["focus_avg"] > 0])),
        "sessions_count": len([s for s in study_sessions
                               if s.start_time and s.start_time.date() >= week_ago])
                           + sum(1 for d in recent_days
                                 if day_data[d].get("_synthetic")
                                 and day_data[d]["study_minutes"] > 0),
    }
    sleep_summary = {
        "avg_hours": round(_safe_mean(
            [day_data[d]["sleep_hours"] for d in recent_days
             if day_data[d]["sleep_hours"] is not None]), 1),
        "nights_logged": len([d for d in recent_days
                              if day_data[d]["sleep_hours"] is not None]),
    }
    mood_summary = {
        "avg_score": round(_safe_mean(
            [day_data[d]["mood_score"] for d in recent_days
             if day_data[d]["mood_score"] > 0]), 1),
        "dominant_mood": _dominant_mood(day_data, week_ago),
    }
    habit_summary = {
        "avg_completion_pct": round(_safe_mean([
            (day_data[d]["habits_done"] / day_data[d]["habits_total"] * 100)
            if day_data[d]["habits_total"] > 0 else 0
            for d in recent_days
        ])),
    }

    month_sched = sum(dd.get("med_scheduled", 0) for dd in day_data.values())
    month_taken = sum(dd.get("med_taken", 0) for dd in day_data.values())
    adherence_pct = round(month_taken / month_sched * 100) if month_sched else None

    # Top symptom types this month
    symptom_type_counts: Counter = Counter()
    for sy in symptom_logs:
        symptom_type_counts[sy.symptom_type] += 1
    top_symptoms = [
        {"type": t, "count": n}
        for t, n in symptom_type_counts.most_common(3)
    ]
    health_summary = {
        "symptom_count_month": len(symptom_logs),
        "symptom_days_month": sum(1 for dd in day_data.values() if dd["symptom_count"] > 0),
        "top_symptoms": top_symptoms,
        "medication_adherence_pct": adherence_pct,
        "medication_scheduled_month": month_sched,
        "medication_taken_month": month_taken,
    }

    # One entry per day (most recent last). Used client-side for things
    # like "what fuels your best days" and "sleep → next-day mood" — charts
    # that need to slice/sort the full 30-day window, not just the last 7.
    day_records_30 = []
    for i in range(30):
        d = today - timedelta(days=29 - i)
        dd = day_data.get(d, _empty_day())
        hb_total = dd.get("habits_total", 0) or 0
        hb_done = dd.get("habits_done", 0) or 0
        day_records_30.append({
            "date": d.isoformat(),
            "dow": d.strftime("%a"),
            "sleep_hours": dd.get("sleep_hours"),
            "mood_score": dd.get("mood_score") or 0,
            "study_minutes": dd.get("study_minutes", 0) or 0,
            "focus_avg": round(dd.get("focus_avg", 0) or 0),
            "habits_done": hb_done,
            "habits_total": hb_total,
            "habits_pct": round(hb_done / hb_total * 100) if hb_total > 0 else None,
            "bedtime_hour": dd.get("bedtime_hour"),
        })

    return {
        "is_synthetic": is_synthetic,
        "real_data_days": real_n,
        "headline": headline,
        "wellness_score": wellness["score"],
        "wellness_breakdown": wellness["breakdown"],
        "wellness_trend": wellness["trend"],
        "wellness_history_14": wellness_history_14,
        "metric_streams_14": metric_streams_14,
        "correlations": correlations,
        "patterns": patterns,
        "recommendations": recommendations,
        "weekly_overview": weekly,
        "day_records_30": day_records_30,
        "rhythms": rhythms,
        "study_summary": study_summary,
        "sleep_summary": sleep_summary,
        "health_summary": health_summary,
        "mood_summary": mood_summary,
        "habit_summary": habit_summary,
        "condition_context": condition_ctx,
        "total_xp": current_user.total_xp,
        "level": current_user.level,
        "streak_days": current_user.streak_days,
    }


#  WELLNESS SCORE (composite across all domains)

def _compute_wellness_score(day_data, week_ago, today, user):
    recent_days = [d for d in day_data if d >= week_ago]

    sleep_hours = [day_data[d]["sleep_hours"] for d in recent_days
                   if day_data[d]["sleep_hours"] is not None]
    if sleep_hours:
        avg_sleep = _safe_mean(sleep_hours)
        if 7 <= avg_sleep <= 9:
            sleep_score = 25
        elif 6 <= avg_sleep < 7 or 9 < avg_sleep <= 10:
            sleep_score = 20
        elif 5 <= avg_sleep < 6 or 10 < avg_sleep <= 11:
            sleep_score = 12
        else:
            sleep_score = 5
    else:
        sleep_score = 10

    mood_scores = [day_data[d]["mood_score"] for d in recent_days
                   if day_data[d]["mood_score"] > 0]
    mood_score = round(_safe_mean(mood_scores) / 5 * 25) if mood_scores else 12

    study_days = [d for d in recent_days if day_data[d]["study_minutes"] > 0]
    study_consistency = len(study_days) / max(len(recent_days), 1)
    focus_vals = [day_data[d]["focus_avg"] for d in recent_days
                  if day_data[d]["focus_avg"] > 0]
    avg_focus = _safe_mean(focus_vals) if focus_vals else 50
    study_score = round((study_consistency * 12.5) + (avg_focus / 100 * 12.5))

    habit_pcts = [
        day_data[d]["habits_done"] / day_data[d]["habits_total"]
        for d in recent_days if day_data[d]["habits_total"] > 0
    ]
    habit_score = round(_safe_mean(habit_pcts) * 25) if habit_pcts else 10

    total = min(100, sleep_score + mood_score + study_score + habit_score)

    prev_week = [d for d in day_data
                 if week_ago - timedelta(days=7) <= d < week_ago]
    if prev_week and recent_days:
        prev_avg_mood = _safe_mean([day_data[d]["mood_score"] for d in prev_week
                                    if day_data[d]["mood_score"] > 0]) or 3
        curr_avg_mood = _safe_mean([day_data[d]["mood_score"] for d in recent_days
                                    if day_data[d]["mood_score"] > 0]) or 3
        if curr_avg_mood > prev_avg_mood + 0.3:
            trend = "improving"
        elif curr_avg_mood < prev_avg_mood - 0.3:
            trend = "declining"
        else:
            trend = "steady"
    else:
        trend = "steady"

    return {
        "score": total,
        "breakdown": {
            "sleep": sleep_score, "mood": mood_score,
            "study": study_score, "habits": habit_score,
        },
        "trend": trend,
    }


#  CORRELATIONS

def _compute_correlations(day_data):
    correlations: List[Dict[str, Any]] = []

    def _habits_ratio(dd):
        total = dd.get("habits_total") or 0
        if total <= 0:
            return None
        return (dd.get("habits_done") or 0) / total

    def _med_adherence(dd):
        scheduled = dd.get("med_scheduled") or 0
        if scheduled <= 0:
            return None
        return (dd.get("med_taken") or 0) / scheduled

    pairs = [
        ("sleep_focus", "Sleep · Focus",
         lambda dd: (dd["sleep_hours"], dd["focus_avg"]),
         lambda dd: dd["sleep_hours"] is not None and dd["focus_avg"] > 0,
         _sleep_focus_insight, True),
        ("sleep_mood", "Sleep · Mood",
         lambda dd: (dd["sleep_hours"], dd["mood_score"]),
         lambda dd: dd["sleep_hours"] is not None and dd["mood_score"] > 0,
         _sleep_mood_insight, False),
        ("sleep_study", "Sleep · Study Time",
         lambda dd: (dd["sleep_hours"], dd["study_minutes"]),
         lambda dd: dd["sleep_hours"] is not None and dd["study_minutes"] > 0,
         _sleep_study_insight, False),
        ("sleep_quality_mood", "Sleep Quality · Mood",
         lambda dd: (dd["sleep_quality"], dd["mood_score"]),
         lambda dd: dd["sleep_quality"] is not None and dd["mood_score"] > 0,
         _sleep_quality_mood_insight, False),
        ("sleep_quality_focus", "Sleep Quality · Focus",
         lambda dd: (dd["sleep_quality"], dd["focus_avg"]),
         lambda dd: dd["sleep_quality"] is not None and dd["focus_avg"] > 0,
         _sleep_quality_focus_insight, False),
        ("mood_study", "Mood · Study Time",
         lambda dd: (dd["mood_score"], dd["study_minutes"]),
         lambda dd: dd["mood_score"] > 0 and dd["study_minutes"] > 0,
         _mood_study_insight, False),
        ("mood_focus", "Mood · Focus",
         lambda dd: (dd["mood_score"], dd["focus_avg"]),
         lambda dd: dd["mood_score"] > 0 and dd["focus_avg"] > 0,
         _mood_focus_insight, False),
        ("habits_mood", "Habits · Mood",
         lambda dd: (_habits_ratio(dd), dd["mood_score"]),
         lambda dd: _habits_ratio(dd) is not None and dd["mood_score"] > 0,
         _habits_mood_insight, False),
        ("habits_focus", "Habits · Focus",
         lambda dd: (_habits_ratio(dd), dd["focus_avg"]),
         lambda dd: _habits_ratio(dd) is not None and dd["focus_avg"] > 0,
         _habits_focus_insight, False),
        ("habits_study", "Habits · Study Time",
         lambda dd: (_habits_ratio(dd), dd["study_minutes"]),
         lambda dd: _habits_ratio(dd) is not None and dd["study_minutes"] > 0,
         _habits_study_insight, False),
        ("habits_sleep", "Habits · Sleep",
         lambda dd: (_habits_ratio(dd), dd["sleep_hours"]),
         lambda dd: _habits_ratio(dd) is not None and dd["sleep_hours"] is not None,
         _habits_sleep_insight, False),
        ("water_focus", "Hydration · Focus",
         lambda dd: (dd["water_ml"], dd["focus_avg"]),
         lambda dd: dd["water_ml"] > 0 and dd["focus_avg"] > 0,
         _water_focus_insight, False),
        ("water_mood", "Hydration · Mood",
         lambda dd: (dd["water_ml"], dd["mood_score"]),
         lambda dd: dd["water_ml"] > 0 and dd["mood_score"] > 0,
         _water_mood_insight, False),
        ("water_study", "Hydration · Study Time",
         lambda dd: (dd["water_ml"], dd["study_minutes"]),
         lambda dd: dd["water_ml"] > 0 and dd["study_minutes"] > 0,
         _water_study_insight, False),
        ("bedtime_quality", "Bedtime · Sleep Quality",
         lambda dd: (dd["bedtime_hour"], dd["sleep_quality"]),
         lambda dd: dd["bedtime_hour"] is not None and dd["sleep_quality"] is not None,
         _bedtime_quality_insight, False),
        ("bedtime_focus", "Bedtime · Next-Day Focus",
         lambda dd: (dd["bedtime_hour"], dd["focus_avg"]),
         lambda dd: dd["bedtime_hour"] is not None and dd["focus_avg"] > 0,
         _bedtime_focus_insight, False),
        ("wake_focus", "Wake Time · Focus",
         lambda dd: (dd["wake_hour"], dd["focus_avg"]),
         lambda dd: dd["wake_hour"] is not None and dd["focus_avg"] > 0,
         _wake_focus_insight, False),
        ("study_symptoms", "Study Duration · Symptom Load",
         lambda dd: (dd["study_minutes"], dd["symptom_intensity"]),
         lambda dd: dd["study_minutes"] > 0,
         _study_symptoms_insight, False),
        ("longsession_symptoms", "Longest Session · Symptom Load",
         lambda dd: (dd["longest_session_min"], dd["symptom_intensity"]),
         lambda dd: dd["longest_session_min"] > 0,
         _long_session_symptom_insight, False),
        ("sleep_symptoms", "Sleep · Symptom Load",
         lambda dd: (dd["sleep_hours"], dd["symptom_intensity"]),
         lambda dd: dd["sleep_hours"] is not None,
         _sleep_symptom_insight, False),
        ("adherence_symptoms", "Medication Adherence · Symptom Load",
         lambda dd: (_med_adherence(dd), dd["symptom_intensity"]),
         lambda dd: _med_adherence(dd) is not None,
         _adherence_symptom_insight, False),
        ("adherence_mood", "Medication Adherence · Mood",
         lambda dd: (_med_adherence(dd), dd["mood_score"]),
         lambda dd: _med_adherence(dd) is not None and dd["mood_score"] > 0,
         _adherence_mood_insight, False),
    ]
    for ctype, label, extractor, gate, insight_fn, pass_avg in pairs:
        paired = [extractor(day_data[d]) for d in day_data if gate(day_data[d])]
        if len(paired) < 3:
            continue
        x = [p[0] for p in paired]
        y = [p[1] for p in paired]
        corr = _pearson(x, y)
        strength = _correlation_strength(corr)
        if pass_avg:
            insight = insight_fn(corr, _safe_mean(x))
        else:
            insight = insight_fn(corr)
        correlations.append({
            "type": ctype,
            "label": label,
            "correlation": round(corr, 2),
            "strength": strength,
            "insight": insight,
            "n_samples": len(paired),
        })

    # These catch delayed signals — e.g. a bad night bending tomorrow's mood,
    # or a skipped med showing up as a symptom the next day.
    lag_specs = [
        ("lag_sleep_mood", "Yesterday's Sleep · Mood",
         lambda prev, cur: (prev["sleep_hours"], cur["mood_score"]),
         lambda prev, cur: prev["sleep_hours"] is not None and cur["mood_score"] > 0,
         _lag_sleep_mood_insight),
        ("lag_mood_study", "Yesterday's Mood · Study Time",
         lambda prev, cur: (prev["mood_score"], cur["study_minutes"]),
         lambda prev, cur: prev["mood_score"] > 0 and cur["study_minutes"] > 0,
         _lag_mood_study_insight),
        ("lag_habits_mood", "Yesterday's Habits · Mood",
         lambda prev, cur: (_habits_ratio(prev), cur["mood_score"]),
         lambda prev, cur: _habits_ratio(prev) is not None and cur["mood_score"] > 0,
         _lag_habits_mood_insight),
        ("lag_sleep_study", "Yesterday's Sleep · Study Time",
         lambda prev, cur: (prev["sleep_hours"], cur["study_minutes"]),
         lambda prev, cur: prev["sleep_hours"] is not None and cur["study_minutes"] > 0,
         _lag_sleep_study_insight),
        ("lag_sleep_focus", "Yesterday's Sleep · Focus",
         lambda prev, cur: (prev["sleep_hours"], cur["focus_avg"]),
         lambda prev, cur: prev["sleep_hours"] is not None and cur["focus_avg"] > 0,
         _lag_sleep_focus_insight),
        ("lag_quality_focus", "Yesterday's Sleep Quality · Focus",
         lambda prev, cur: (prev["sleep_quality"], cur["focus_avg"]),
         lambda prev, cur: prev["sleep_quality"] is not None and cur["focus_avg"] > 0,
         _lag_quality_focus_insight),
        ("lag_bedtime_mood", "Yesterday's Bedtime · Mood",
         lambda prev, cur: (prev["bedtime_hour"], cur["mood_score"]),
         lambda prev, cur: prev["bedtime_hour"] is not None and cur["mood_score"] > 0,
         _lag_bedtime_mood_insight),
        ("lag_skip_symptoms", "Yesterday's Medication Skip · Symptom Load",
         lambda prev, cur: (
             (1 if (_med_adherence(prev) is not None and _med_adherence(prev) < 1.0) else 0),
             cur["symptom_intensity"],
         ),
         lambda prev, cur: _med_adherence(prev) is not None,
         _lag_skip_symptoms_insight),
        ("lag_study_symptoms", "Yesterday's Study Load · Symptom Load",
         lambda prev, cur: (prev["study_minutes"], cur["symptom_intensity"]),
         lambda prev, cur: prev["study_minutes"] > 0,
         _lag_study_symptoms_insight),
    ]
    sorted_dates = sorted(day_data.keys())
    date_idx = {d: i for i, d in enumerate(sorted_dates)}
    for ctype, label, extractor, gate, insight_fn in lag_specs:
        paired = []
        for d in sorted_dates:
            prev = d - timedelta(days=1)
            if prev not in day_data:
                continue
            prev_dd = day_data[prev]
            cur_dd = day_data[d]
            if gate(prev_dd, cur_dd):
                paired.append(extractor(prev_dd, cur_dd))
        if len(paired) < 3:
            continue
        x = [p[0] for p in paired]
        y = [p[1] for p in paired]
        corr = _pearson(x, y)
        correlations.append({
            "type": ctype,
            "label": label,
            "correlation": round(corr, 2),
            "strength": _correlation_strength(corr),
            "insight": insight_fn(corr),
            "n_samples": len(paired),
        })

    # Relevance filter: only surface correlations with real signal.
    # |r| >= 0.3 is the "worth mentioning" threshold in behavioral data —
    # anything below that is basically noise to a student user, even if
    # it's technically nonzero. Paired with n >= 7 so the number isn't
    # driven by 2–3 lucky days.
    CORR_MIN_ABS = 0.3
    CORR_MIN_N = 7
    correlations = [
        c for c in correlations
        if abs(c["correlation"]) >= CORR_MIN_ABS
        and c["n_samples"] >= CORR_MIN_N
    ]

    # Sort by absolute correlation strength so the most striking sit on top.
    correlations.sort(key=lambda c: abs(c["correlation"]), reverse=True)

    # Cap at 10 so the page never becomes a wall of cards — the user asked
    # for the most *relevant* ones up top, not an exhaustive dump.
    correlations = correlations[:10]

    # Flag the top few for UI prominence. The frontend uses this to render
    # the strongest link(s) as a featured card and the rest in a compact row.
    for i, c in enumerate(correlations):
        c["rank"] = i  # 0 = strongest
        c["is_headline"] = i == 0 and abs(c["correlation"]) >= 0.35
    return correlations


def _pearson(x: List[float], y: List[float]) -> float:
    n = len(x)
    if n < 2:
        return 0.0
    mean_x = sum(x) / n
    mean_y = sum(y) / n
    num = sum((xi - mean_x) * (yi - mean_y) for xi, yi in zip(x, y))
    den_x = sum((xi - mean_x) ** 2 for xi in x) ** 0.5
    den_y = sum((yi - mean_y) ** 2 for yi in y) ** 0.5
    if den_x == 0 or den_y == 0:
        return 0.0
    return num / (den_x * den_y)


def _correlation_strength(r: float) -> str:
    ar = abs(r)
    if ar >= 0.7:
        return "strong"
    if ar >= 0.4:
        return "moderate"
    if ar >= 0.2:
        return "weak"
    return "negligible"


def _sleep_focus_insight(corr, avg_sleep):
    if corr > 0.4:
        return f"Better sleep clearly lifts your focus. Your avg is {avg_sleep:.1f}h — defend the 7–9h window."
    if corr > 0.2:
        return "Mild link between your sleep and focus. Keep logging — it'll sharpen."
    if corr < -0.2:
        return "More sleep doesn't always equal better focus for you. Quality > quantity?"
    return "No clear pattern yet between sleep and focus."


def _mood_study_insight(corr):
    if corr > 0.4:
        return "You crush study time on good-mood days. Schedule heavy lifts for those."
    if corr > 0.2:
        return "Positive mood mildly boosts your study time."
    if corr < -0.2:
        return "You sometimes lean into study on tougher days — that's a healthy coping habit."
    return "Your study habit is fairly mood-independent — solid discipline."


def _sleep_mood_insight(corr):
    if corr > 0.4:
        return "Sleep is one of your biggest mood levers. Protect bedtimes."
    if corr > 0.2:
        return "More sleep tends to lift your mood a notch."
    return "Your mood seems pretty independent of sleep duration this stretch."


def _habits_mood_insight(corr):
    if corr > 0.4:
        return "Completing habits noticeably boosts your mood. Keep the streaks alive."
    if corr > 0.2:
        return "Habit completion gives you a mild mood lift."
    return "Your mood doesn't track habits directly — they still build discipline."


def _water_focus_insight(corr):
    if corr > 0.3:
        return "Your hydration tracks with sharper focus. Keep the bottle nearby."
    if corr < -0.2:
        return "Lots of water on dim-focus days — could be afternoon fatigue, not dehydration."
    return "Hydration's contribution to your focus is unclear yet."


def _sleep_study_insight(corr):
    if corr > 0.4:
        return "Well-rested nights clearly buy you more study time the next day."
    if corr > 0.2:
        return "Sleep gives your study time a gentle lift."
    if corr < -0.2:
        return "Oddly, longer sleep doesn't translate into longer study — check what's eating the day."
    return "Sleep duration and study time aren't tightly linked right now."


def _sleep_quality_mood_insight(corr):
    if corr > 0.4:
        return "How well you sleep outranks how long you sleep for your mood. Guard quality."
    if corr > 0.2:
        return "Better sleep quality mildly lifts your mood."
    return "Sleep quality and mood aren't moving together much this stretch."


def _sleep_quality_focus_insight(corr):
    if corr > 0.4:
        return "Deeper sleep shows up as sharper focus the next day."
    if corr > 0.2:
        return "Higher quality sleep gives focus a small edge."
    return "Your focus doesn't appear tied to sleep-quality ratings yet."


def _mood_focus_insight(corr):
    if corr > 0.4:
        return "Good-mood days are high-focus days. Schedule your hardest work there."
    if corr > 0.2:
        return "Mood mildly nudges your focus — worth noticing."
    if corr < -0.2:
        return "You can occasionally dial up focus on tough-mood days — good discipline."
    return "Focus isn't closely tracking mood day-to-day."


def _habits_focus_insight(corr):
    if corr > 0.4:
        return "Habit completion is a strong leading indicator of focus. Keep stacking wins."
    if corr > 0.2:
        return "Ticking habits gently raises your focus ceiling."
    return "Habits aren't moving your focus much directly — that's fine; they build structure."


def _habits_study_insight(corr):
    if corr > 0.4:
        return "On habit-heavy days you also study more. Anchor one habit to your study block."
    if corr > 0.2:
        return "Habits and study time rise and fall together a little."
    return "Habit completion and study time look fairly independent."


def _habits_sleep_insight(corr):
    if corr > 0.3:
        return "Habit days and good-sleep days coincide — the structure is paying off."
    if corr < -0.2:
        return "Habit-heavy days sometimes cost you sleep — watch for late-night rushes."
    return "Habit completion and sleep length don't track each other strongly."


def _water_mood_insight(corr):
    if corr > 0.3:
        return "Hydrated days lift your mood — keep the bottle visible."
    if corr < -0.2:
        return "More water on low-mood days — likely compensation, not causation."
    return "Hydration and mood aren't tightly linked right now."


def _water_study_insight(corr):
    if corr > 0.3:
        return "Your best-hydrated days also tend to be your longest study days."
    return "Hydration and study duration aren't moving together clearly."


def _lag_sleep_mood_insight(corr):
    if corr > 0.4:
        return "Last night's sleep is a strong predictor of today's mood. Protect bedtimes."
    if corr > 0.2:
        return "Previous night's sleep gives today's mood a small lift."
    if corr < -0.2:
        return "Curious inverse — sleep one day seems to dent mood the next. Watch for oversleep."
    return "No strong overnight carry-over from sleep to next-day mood yet."


def _lag_mood_study_insight(corr):
    if corr > 0.4:
        return "A good-mood day fuels the next day's study. Use momentum while you have it."
    if corr > 0.2:
        return "Yesterday's mood slightly nudges today's study output."
    return "Day-after study output isn't strongly mood-driven for you."


def _lag_habits_mood_insight(corr):
    if corr > 0.3:
        return "Habit days make tomorrow's mood better — compounding pays off."
    return "No strong overnight mood return from habits yet — keep stacking them anyway."


def _bedtime_quality_insight(corr):
    if corr < -0.4:
        return "Earlier bedtimes deliver clearly deeper sleep. Aim for the same window each night."
    if corr < -0.2:
        return "Going to bed earlier modestly improves your sleep quality."
    if corr > 0.2:
        return "Curiously, your later nights rate higher quality — could be alcohol-free or quieter weekends."
    return "Bedtime hour and sleep quality aren't strongly linked yet."


def _bedtime_focus_insight(corr):
    if corr < -0.4:
        return "Late bedtimes visibly cost you focus the next day. Lock a bedtime and protect it."
    if corr < -0.2:
        return "Later bedtimes mildly dent your next-day focus."
    return "Bedtime hour isn't pulling on your next-day focus much yet."


def _wake_focus_insight(corr):
    if corr < -0.3:
        return "Earlier wake times line up with sharper focus. Front-load deep work."
    if corr > 0.3:
        return "Later starts give you better focus — your prime hours are mid-day onward."
    return "Wake time isn't a strong driver of your focus right now."


def _study_symptoms_insight(corr):
    if corr > 0.4:
        return "Long study days clearly raise your symptom load. Build in 10-min breaks every hour."
    if corr > 0.2:
        return "Heavier study days carry slightly more symptoms — micro-breaks help."
    return "Study volume isn't driving symptoms — your pacing is solid."


def _long_session_symptom_insight(corr):
    if corr > 0.4:
        return "Marathon sessions trigger headaches/eye-strain. Cap individual blocks at ~75 min."
    if corr > 0.2:
        return "Your longest blocks of the day mildly raise symptom risk."
    return "No clear link between session length and symptoms yet."


def _sleep_symptom_insight(corr):
    if corr < -0.3:
        return "Short-sleep nights bring more symptoms. Sleep is your top preventative lever."
    if corr < -0.2:
        return "Less sleep mildly raises your symptom load."
    return "Sleep duration and symptoms aren't tightly tied for you yet."


def _adherence_symptom_insight(corr):
    if corr < -0.3:
        return "When you stay on your meds, symptoms drop. Adherence is paying off — keep streaks."
    if corr > 0.3:
        return "Counter-intuitive: symptoms rise on adherent days — possible side-effect timing, worth a chat with your provider."
    return "Med adherence isn't the dominant driver of symptoms in your data."


def _adherence_mood_insight(corr):
    if corr > 0.3:
        return "Sticking to your medication schedule lifts your mood meaningfully."
    if corr < -0.3:
        return "Mood dips on adherent days — possible side-effect window. Note when symptoms hit."
    return "Mood isn't tightly linked to adherence in your data."


def _lag_sleep_study_insight(corr):
    if corr > 0.4:
        return "A great night's sleep buys you measurably more study the next day. Protect bedtimes."
    if corr > 0.2:
        return "Better sleep slightly extends your next-day study time."
    return "Yesterday's sleep isn't strongly predicting today's study output."


def _lag_sleep_focus_insight(corr):
    if corr > 0.4:
        return "Last night's sleep is your best focus predictor. Plan deep work after a good night."
    if corr > 0.2:
        return "Previous-night sleep gives next-day focus a small bump."
    return "Overnight focus carry-over from sleep is muted right now."


def _lag_quality_focus_insight(corr):
    if corr > 0.4:
        return "Deep, restorative sleep shows up the next day as sharper focus. Quality over quantity."
    if corr > 0.2:
        return "Higher quality sleep gives next-day focus a small lift."
    return "Sleep quality and next-day focus aren't strongly linked yet."


def _lag_bedtime_mood_insight(corr):
    if corr < -0.3:
        return "Late nights drag tomorrow's mood down. Even a 30-min earlier bedtime helps."
    if corr < -0.2:
        return "Going to bed later mildly hurts your next-day mood."
    return "Bedtime hour isn't strongly predicting next-day mood for you."


def _lag_skip_symptoms_insight(corr):
    if corr > 0.3:
        return "Skipping medication clearly raises next-day symptoms. The streak matters."
    if corr > 0.2:
        return "Missed doses bump tomorrow's symptom risk slightly."
    return "Missed doses aren't the main symptom driver in your data."


def _lag_study_symptoms_insight(corr):
    if corr > 0.3:
        return "Heavy study days are followed by symptoms next day — recovery time matters."
    if corr > 0.2:
        return "A long-study day mildly raises tomorrow's symptom risk."
    return "Study load isn't strongly tied to next-day symptoms."


#  PATTERN DETECTION

def _detect_patterns(day_data, sleep_logs, mood_entries, study_sessions):
    patterns = []

    # 1. Best study day-of-week
    day_minutes: Dict[str, List[int]] = defaultdict(list)
    for d, dd in day_data.items():
        if dd["study_minutes"] > 0:
            day_minutes[d.strftime("%A")].append(dd["study_minutes"])
    if day_minutes:
        best_day = max(day_minutes, key=lambda k: _safe_mean(day_minutes[k]))
        avg_mins = round(_safe_mean(day_minutes[best_day]))
        patterns.append({
            "type": "best_study_day", "title": "Peak Study Day",
            "description": f"You study most on {best_day}s — averaging {avg_mins} min.",
            "icon": "trending_up", "severity": "positive",
        })

    # 2. Sleep consistency
    sleep_hours_list = [
        dd["sleep_hours"] for dd in day_data.values()
        if dd["sleep_hours"] is not None
    ]
    if len(sleep_hours_list) >= 5:
        std_dev = _std_dev(sleep_hours_list)
        if std_dev < 0.8:
            patterns.append({
                "type": "sleep_consistent", "title": "Consistent Sleeper",
                "description": f"Your sleep varies by only {std_dev:.1f}h — great consistency!",
                "icon": "hotel", "severity": "positive",
            })
        elif std_dev > 1.5:
            patterns.append({
                "type": "sleep_irregular", "title": "Irregular Sleep",
                "description": f"Your sleep varies by {std_dev:.1f}h — try a consistent bedtime.",
                "icon": "warning", "severity": "warning",
            })

    # 3. Late-night study detection (real sessions only — synthetic data
    # doesn't have hourly context)
    late_sessions = [
        s for s in study_sessions
        if s.start_time and s.start_time.hour >= 22
    ]
    if len(late_sessions) >= 3:
        patterns.append({
            "type": "night_owl", "title": "Night Owl Alert",
            "description": f"You've had {len(late_sessions)} late-night study sessions. "
                            "Earlier sessions usually retain better.",
            "icon": "dark_mode", "severity": "info",
        })

    # 4. Mood stability
    mood_scores = [dd["mood_score"] for dd in day_data.values()
                   if dd["mood_score"] > 0]
    if len(mood_scores) >= 5:
        mood_std = _std_dev(mood_scores)
        if mood_std < 0.8:
            patterns.append({
                "type": "stable_mood", "title": "Emotionally Steady",
                "description": "Your mood has been stable — great for sustained productivity.",
                "icon": "sentiment_satisfied", "severity": "positive",
            })
        elif mood_std > 1.5:
            patterns.append({
                "type": "mood_volatile", "title": "Mood Swings Detected",
                "description": "Your mood fluctuates significantly. Journaling or movement can help.",
                "icon": "swap_vert", "severity": "warning",
            })

    # 5. Habit streak
    habit_completion_streak = 0
    today = date.today()
    for i in range(30):
        d = today - timedelta(days=i)
        if (day_data.get(d, {}).get("habits_done", 0) > 0):
            habit_completion_streak += 1
        else:
            break
    if habit_completion_streak >= 7:
        patterns.append({
            "type": "habit_streak",
            "title": f"{habit_completion_streak}-Day Habit Streak!",
            "description": f"You've completed habits for {habit_completion_streak} days straight.",
            "icon": "local_fire_department", "severity": "positive",
        })

    # 6. Best-rested day → highest focus signal
    by_rest_focus: List[Tuple[float, float]] = []
    for dd in day_data.values():
        if dd["sleep_hours"] is not None and dd["focus_avg"] > 0:
            by_rest_focus.append((dd["sleep_hours"], dd["focus_avg"]))
    if len(by_rest_focus) >= 4:
        # Compare top-third sleep vs bottom-third sleep avg focus.
        by_rest_focus.sort(key=lambda p: p[0])
        third = max(1, len(by_rest_focus) // 3)
        bottom = _safe_mean([p[1] for p in by_rest_focus[:third]])
        top = _safe_mean([p[1] for p in by_rest_focus[-third:]])
        delta = top - bottom
        if delta >= 8:
            patterns.append({
                "type": "rest_to_focus", "title": "Rest → Focus Boost",
                "description": f"Focus is {delta:.0f} pts higher on your best-rested days.",
                "icon": "trending_up", "severity": "positive",
            })

    # 7. Peak focus window — which 2-hour window has your best avg focus?
    # Works off the (hour, duration, focus) tuples we recorded per day.
    hour_focus: Dict[int, List[float]] = defaultdict(list)
    for dd in day_data.values():
        for hr, _dur, focus in dd.get("session_hours", []):
            if focus and focus > 0:
                hour_focus[hr % 24].append(focus)
    # Average focus per hour
    avg_by_hour = {h: _safe_mean(v) for h, v in hour_focus.items()
                   if len(v) >= 2}
    if len(avg_by_hour) >= 4:
        # Find the best 2-hour contiguous band
        best_band = None
        best_score = 0.0
        for h in range(24):
            band = [avg_by_hour.get(h, 0), avg_by_hour.get((h + 1) % 24, 0)]
            band = [b for b in band if b > 0]
            if len(band) < 2:
                continue
            score = sum(band) / len(band)
            if score > best_score:
                best_score = score
                best_band = (h, (h + 1) % 24)
        overall_avg = _safe_mean(list(avg_by_hour.values()))
        if best_band and best_score >= max(60, overall_avg + 6):
            lo, hi = best_band
            patterns.append({
                "type": "peak_focus_window",
                "title": "Peak Focus Window",
                "description": f"Your focus peaks between {_fmt_hour(lo)}–{_fmt_hour(hi + 1)} "
                               f"({best_score:.0f}/100). Schedule hardest work there.",
                "icon": "schedule", "severity": "positive",
                "meta": {"start_hour": lo, "end_hour": (hi + 1) % 24,
                         "avg_focus": round(best_score)},
            })

    # 8. Golden bedtime — which bedtime hour gives best sleep quality?
    bed_quality_buckets: Dict[int, List[int]] = defaultdict(list)
    for dd in day_data.values():
        if dd.get("bedtime_hour") is not None and dd.get("sleep_quality") is not None:
            # Bucket by rounded hour (cap at 30 = 6am)
            bucket = int(min(30, round(dd["bedtime_hour"])))
            bed_quality_buckets[bucket].append(dd["sleep_quality"])
    scored = [
        (hr, _safe_mean(qs)) for hr, qs in bed_quality_buckets.items()
        if len(qs) >= 2
    ]
    if len(scored) >= 2:
        scored.sort(key=lambda p: -p[1])
        best_hr, best_q = scored[0]
        worst_hr, worst_q = scored[-1]
        if best_q - worst_q >= 1.0:
            patterns.append({
                "type": "golden_bedtime",
                "title": "Golden Bedtime Window",
                "description": f"Sleep quality peaks at {best_q:.1f}/5 when in bed "
                               f"around {_fmt_hour(best_hr % 24)} — "
                               f"{(best_q - worst_q):.1f} pts above your late nights.",
                "icon": "nightlight", "severity": "positive",
                "meta": {"best_hour": best_hr, "best_quality": round(best_q, 1)},
            })

    # 9. Bedtime consistency
    bedtimes = [dd["bedtime_hour"] for dd in day_data.values()
                if dd.get("bedtime_hour") is not None]
    if len(bedtimes) >= 7:
        std = _std_dev(bedtimes)
        if std < 0.9:
            patterns.append({
                "type": "bedtime_consistent", "title": "Locked-In Bedtime",
                "description": f"Bedtime varies by only {std:.1f}h — "
                               "your circadian rhythm will thank you.",
                "icon": "lock_clock", "severity": "positive",
            })
        elif std > 2.0:
            patterns.append({
                "type": "bedtime_erratic", "title": "Erratic Bedtime",
                "description": f"Bedtime swings by {std:.1f}h — pick a target "
                               "window and defend it for a week.",
                "icon": "sync_problem", "severity": "warning",
            })

    # 10. Long-session risk — how often do >90-min sessions coincide with symptoms?
    long_days = [dd for dd in day_data.values()
                 if dd.get("longest_session_min", 0) >= 90]
    if len(long_days) >= 4:
        with_symptom = sum(1 for dd in long_days if dd["symptom_count"] > 0)
        ratio = with_symptom / len(long_days)
        if ratio >= 0.5:
            patterns.append({
                "type": "long_session_risk",
                "title": "Long-Session Symptom Link",
                "description": f"{int(ratio * 100)}% of your 90+ min sessions "
                               "coincide with symptoms. Cap blocks at 75 min.",
                "icon": "hourglass_bottom", "severity": "warning",
            })

    # 11. Medication adherence summary
    total_sched = sum(dd.get("med_scheduled", 0) for dd in day_data.values())
    total_taken = sum(dd.get("med_taken", 0) for dd in day_data.values())
    if total_sched >= 10:
        adherence = total_taken / total_sched
        if adherence >= 0.95:
            patterns.append({
                "type": "med_adherent", "title": "Medication Streak",
                "description": f"{int(adherence * 100)}% adherence — excellent. "
                               "The consistency is doing its job.",
                "icon": "verified", "severity": "positive",
                "meta": {"adherence_pct": round(adherence * 100)},
            })
        elif adherence < 0.8:
            patterns.append({
                "type": "med_skips", "title": "Missed Doses",
                "description": f"Adherence sitting at {int(adherence * 100)}%. "
                               "Skipping raises your next-day symptom risk.",
                "icon": "report", "severity": "warning",
                "meta": {"adherence_pct": round(adherence * 100)},
            })

    # 12. Mood dip day — which weekday drags mood down?
    weekday_mood: Dict[int, List[int]] = defaultdict(list)
    for d, dd in day_data.items():
        if dd["mood_score"] > 0:
            weekday_mood[d.weekday()].append(dd["mood_score"])
    day_avgs = [(wd, _safe_mean(v))
                for wd, v in weekday_mood.items() if len(v) >= 2]
    if len(day_avgs) >= 5:
        day_avgs.sort(key=lambda p: p[1])
        worst_wd, worst_avg = day_avgs[0]
        best_wd, best_avg = day_avgs[-1]
        if best_avg - worst_avg >= 0.8:
            day_names = ["Monday", "Tuesday", "Wednesday", "Thursday",
                         "Friday", "Saturday", "Sunday"]
            patterns.append({
                "type": "mood_dip_day", "title": f"{day_names[worst_wd]} Dip",
                "description": f"Your mood is lowest on {day_names[worst_wd]}s "
                               f"({worst_avg:.1f}/5) and highest on "
                               f"{day_names[best_wd]}s ({best_avg:.1f}/5).",
                "icon": "event_busy", "severity": "info",
                "meta": {"dip_day": day_names[worst_wd],
                         "peak_day": day_names[best_wd]},
            })

    # 13. Symptom frequency flag
    symptom_days = sum(1 for dd in day_data.values() if dd["symptom_count"] > 0)
    total_tracked_days = sum(1 for dd in day_data.values()
                              if dd["sleep_hours"] is not None or dd["mood_score"] > 0)
    if total_tracked_days >= 14 and symptom_days / total_tracked_days >= 0.35:
        patterns.append({
            "type": "symptom_frequent",
            "title": "Symptoms Showing Up Often",
            "description": f"Symptoms on {symptom_days} of your last {total_tracked_days} "
                           "tracked days. Check triggers: late nights, long sessions, "
                           "missed meds.",
            "icon": "healing", "severity": "warning",
        })

    return patterns


def _fmt_hour(h: int) -> str:
    h = h % 24
    suffix = "AM" if h < 12 else "PM"
    hh = h % 12 or 12
    return f"{hh} {suffix}"


def _std_dev(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    return variance ** 0.5


#  RECOMMENDATIONS

def _generate_recommendations(wellness, correlations, patterns, day_data, user):
    recs = []
    score = wellness["score"]
    breakdown = wellness["breakdown"]

    if breakdown["sleep"] < 15:
        recs.append({
            "category": "sleep", "priority": "high",
            "title": "Defend your sleep window",
            "description": "Aim for 7–9 hours and keep a consistent bedtime — it's the highest-leverage tweak you can make.",
            "icon": "bedtime", "deeplink": "/health/sleep",
        })
    if breakdown["mood"] < 12:
        recs.append({
            "category": "mood", "priority": "medium",
            "title": "Mood check-in",
            "description": "Mood has been low. Try one mood-lifter today — a walk, a friend, music — and log how you feel from the dashboard.",
            "icon": "mood", "deeplink": "/home",
        })
    if breakdown["study"] < 12:
        recs.append({
            "category": "study", "priority": "high",
            "title": "Rebuild study consistency",
            "description": "Even one daily 25-min Pomodoro is enough to compound. Open a session right now.",
            "icon": "school", "deeplink": "/study/session",
        })
    if breakdown["habits"] < 12:
        recs.append({
            "category": "habits", "priority": "medium",
            "title": "Pick one habit to anchor",
            "description": "Knock out one habit today — momentum beats motivation.",
            "icon": "check_circle", "deeplink": "/home",
        })

    # Cross-domain: leverage strongest correlation
    for corr in correlations:
        if corr["type"] == "sleep_focus" and corr["correlation"] > 0.4:
            recs.append({
                "category": "cross_domain", "priority": "high",
                "title": "Sleep is your focus multiplier",
                "description": f"Your sleep–focus link is {corr['strength']}. Plan deep-work sessions for the day after your best-rested night.",
                "icon": "insights", "deeplink": "/health/sleep",
            })
            break

    if user.streak_days >= 3:
        recs.append({
            "category": "motivation", "priority": "low",
            "title": f"Don't break the {user.streak_days}-day streak",
            "description": "Tap one small action today — anything that counts. Future-you will thank you.",
            "icon": "local_fire_department", "deeplink": "/home",
        })

    if score >= 80:
        recs.append({
            "category": "celebration", "priority": "low",
            "title": "You're in great shape",
            "description": f"Wellness score of {score}/100 — keep doing whatever you're doing.",
            "icon": "emoji_events", "deeplink": None,
        })

    # Pattern-driven recs — these are where CEREBRO feels smart because
    # they translate detected patterns into *actions* the student can take.
    for p in patterns:
        if p["type"] == "night_owl":
            recs.append({
                "category": "study", "priority": "medium",
                "title": "Push your study earlier",
                "description": "Late-night cramming hurts retention. Try to wrap by 10pm and review in the morning.",
                "icon": "bedtime", "deeplink": "/study/session",
            })
        if p["type"] == "mood_volatile":
            recs.append({
                "category": "mood", "priority": "medium",
                "title": "Add a mood anchor",
                "description": "On unstable days, try a 5-minute breath or a quick walk, then log the shift from the dashboard.",
                "icon": "mood", "deeplink": "/home",
            })
        if p["type"] == "peak_focus_window":
            meta = p.get("meta", {})
            start_h = meta.get("start_hour")
            end_h = meta.get("end_hour")
            if start_h is not None:
                recs.append({
                    "category": "schedule", "priority": "high",
                    "title": "Schedule deep work in your peak window",
                    "description": f"Your focus averages {meta.get('avg_focus')}/100 "
                                   f"between {_fmt_hour(start_h)} and {_fmt_hour(end_h)}. "
                                   "Put your hardest sessions + practice tests there.",
                    "icon": "schedule", "deeplink": "/study/calendar",
                })
        if p["type"] == "golden_bedtime":
            meta = p.get("meta", {})
            best_h = meta.get("best_hour")
            if best_h is not None:
                recs.append({
                    "category": "sleep", "priority": "high",
                    "title": "Lock your golden bedtime",
                    "description": f"You sleep deepest when in bed around {_fmt_hour(best_h % 24)}. "
                                   "Set a wind-down alarm 45 minutes before.",
                    "icon": "nightlight", "deeplink": "/health/sleep",
                })
        if p["type"] == "long_session_risk":
            recs.append({
                "category": "health", "priority": "high",
                "title": "Break up your long blocks",
                "description": "Your 90+ min sessions are tripping symptoms. "
                               "Try 50-min Pomodoros with a 10-min screen-free break.",
                "icon": "hourglass_bottom", "deeplink": "/study/session",
            })
        if p["type"] == "med_skips":
            recs.append({
                "category": "health", "priority": "high",
                "title": "Protect your medication streak",
                "description": f"Adherence at {p.get('meta', {}).get('adherence_pct', 'low')}%. "
                               "Stack it onto an existing routine — brush teeth, then meds.",
                "icon": "medication", "deeplink": "/health/medications",
            })
        if p["type"] == "bedtime_erratic":
            recs.append({
                "category": "sleep", "priority": "medium",
                "title": "Settle on a bedtime window",
                "description": "Even a 30-minute window beats a 2-hour range. "
                               "Pick a 60-min target and log to it for a week.",
                "icon": "lock_clock", "deeplink": "/health/sleep",
            })
        if p["type"] == "symptom_frequent":
            recs.append({
                "category": "health", "priority": "high",
                "title": "Audit your symptom triggers",
                "description": "Open your symptom log and look for the top 2 triggers. "
                               "Fix one at a time — sleep first usually helps most.",
                "icon": "healing", "deeplink": "/health/symptoms",
            })
        if p["type"] == "mood_dip_day":
            dip = p.get("meta", {}).get("dip_day", "that day")
            recs.append({
                "category": "mood", "priority": "low",
                "title": f"Plan something lighter on {dip}s",
                "description": f"Your mood consistently dips on {dip}. "
                               "Block a short walk or a social thing to buffer it.",
                "icon": "event_available", "deeplink": "/study/calendar",
            })

    # Correlation-driven: if medication adherence correlates strongly with
    # low symptom load, elevate adherence as a priority.
    for c in correlations:
        if c["type"] == "adherence_symptoms" and c["correlation"] < -0.3:
            recs.append({
                "category": "health", "priority": "high",
                "title": "Your meds are doing the job",
                "description": "Data shows symptoms drop meaningfully when you stay on schedule. "
                               "Don't skip — even on good days.",
                "icon": "medication", "deeplink": "/health/medications",
            })
            break
        if c["type"] == "lag_sleep_focus" and c["correlation"] > 0.4:
            recs.append({
                "category": "schedule", "priority": "medium",
                "title": "Pair top-focus tasks with best-rested days",
                "description": "After any 7.5+ hour night, schedule a practice test or a deep-work session — that's when you retain most.",
                "icon": "insights", "deeplink": "/study/calendar",
            })
            break

    return recs[:10]


#  HEADLINE — single sentence narrative

def _build_headline(wellness, correlations, patterns, day_data, today, is_synthetic):
    score = wellness["score"]
    trend = wellness["trend"]

    # Pick the most striking correlation if any
    strong = next((c for c in correlations if abs(c["correlation"]) >= 0.4), None)
    if strong:
        sign = "lifts" if strong["correlation"] > 0 else "bends"
        # Labels use " · " (middle dot) as separator. Fall back to " ↔ "
        # for any older cached payload defensively.
        sep = " · " if " · " in strong["label"] else " ↔ "
        try:
            a, b = strong["label"].split(sep, 1)
        except ValueError:
            a, b = strong["label"], "wellness"
        sentence = f"{a} {sign} your {b.lower()} — wellness {trend} at {score}/100."
    elif patterns:
        sentence = f"{patterns[0]['title']}: {patterns[0]['description']}"
    else:
        sentence = f"Wellness sits at {score}/100 — {trend}. Keep logging to unlock patterns."

    if is_synthetic:
        return sentence + " (preview using sample data — your real story will replace this as you log.)"
    return sentence


#  CONDITION-AWARE CONTEXT
#  Turns the user's wizard-collected medical_conditions + medications
#  into the "aware smart app" layer the client uses to:
#    • personalise the symptom picker (already handled client-side)
#    • highlight symptoms to watch for
#    • surface condition-specific coaching tips

# Condition → {watch_symptoms, tip} tuple. Short, actionable, and
# pulled from common clinical guidance — not medical advice, just
# surfaced nudges. Keys are lowercased substrings so we match free-
# form entries like "Migraines" or "chronic migraine".
_CONDITION_KB: Dict[str, Dict[str, Any]] = {
    "migraine": {
        "label": "Migraine",
        "watch_symptoms": ["Aura", "Photophobia", "Phonophobia", "Throbbing Pain", "Nausea"],
        "tip": "Dehydration and under-sleep are the two most common migraine triggers — aim for 2L water and 7h+ sleep on study-heavy days.",
        "related_metrics": ["sleep_hours", "water_ml"],
    },
    "adhd": {
        "label": "ADHD",
        "watch_symptoms": ["Brain Fog", "Restlessness", "Focus Crash", "Appetite Loss", "Insomnia"],
        "tip": "Body-double or time-box your hardest work in your peak-focus window; medication effects fade late afternoon so plan reviews then.",
        "related_metrics": ["focus_score", "study_minutes"],
    },
    "anxiety": {
        "label": "Anxiety",
        "watch_symptoms": ["Racing Heart", "Chest Tightness", "Restlessness", "Shortness of Breath", "Panic"],
        "tip": "A 90-second box-breath before study blocks measurably drops heart rate. Log it as a relief method to see what actually helps.",
        "related_metrics": ["mood_score", "sleep_hours"],
    },
    "depression": {
        "label": "Depression",
        "watch_symptoms": ["Fatigue", "Low Motivation", "Brain Fog", "Insomnia"],
        "tip": "Tiny wins compound — one habit + one 25-min session is enough today. Mood tends to follow action, not the other way round.",
        "related_metrics": ["mood_score", "habits_done"],
    },
    "pcos": {
        "label": "PCOS",
        "watch_symptoms": ["Cramps", "Bloating", "Fatigue", "Mood Swings", "Acne Flare"],
        "tip": "Symptom intensity often tracks with cycle phase — log consistently for a month so CEREBRO can flag your heaviest days in advance.",
        "related_metrics": ["mood_score", "symptom_count"],
    },
    "asthma": {
        "label": "Asthma",
        "watch_symptoms": ["Shortness of Breath", "Wheezing", "Chest Tightness", "Cough"],
        "tip": "Cold or high-pollen days + heavy study = higher flare risk. Keep your reliever inhaler close and log any tightness immediately.",
        "related_metrics": ["symptom_count"],
    },
    "diabetes": {
        "label": "Diabetes",
        "watch_symptoms": ["Low Blood Sugar", "High Blood Sugar", "Thirst", "Blurred Vision", "Fatigue"],
        "tip": "Long study blocks without a snack are the #1 blood-sugar dip culprit. Schedule a fuel break every 90 minutes.",
        "related_metrics": ["study_minutes", "water_ml"],
    },
    "ibs": {
        "label": "IBS",
        "watch_symptoms": ["Bloating", "Cramps", "Diarrhea", "Constipation", "Stomach Pain"],
        "tip": "Stress + coffee is IBS's favourite pairing. When you log flares, also log caffeine intake so CEREBRO can spot the pattern.",
        "related_metrics": ["symptom_count", "mood_score"],
    },
    "insomnia": {
        "label": "Insomnia",
        "watch_symptoms": ["Exhaustion", "Brain Fog", "Irritability", "Headache"],
        "tip": "Consistency beats duration. Pick one bedtime you can actually hit 5/7 nights — CEREBRO will track the streak for you.",
        "related_metrics": ["sleep_hours", "bedtime_hour"],
    },
    "hypertension": {
        "label": "Hypertension",
        "watch_symptoms": ["Headache", "Dizziness", "Chest Tightness"],
        "tip": "Caffeine + short sleep is a pressure spike combo. Swap one coffee for water on low-sleep days.",
        "related_metrics": ["sleep_hours", "water_ml"],
    },
    "dyslexia": {
        "label": "Dyslexia",
        "watch_symptoms": ["Eye Strain", "Focus Crash", "Brain Fog"],
        "tip": "Use text-to-speech for long readings and chunk sessions into 20-min blocks — retention stays higher than 60-min marathons.",
        "related_metrics": ["focus_score"],
    },
    "eczema": {
        "label": "Eczema",
        "watch_symptoms": ["Skin Itch", "Skin Flare", "Dry Skin"],
        "tip": "Stress-linked flares are real. When symptom intensity spikes, pair it with a mood log so CEREBRO can catch the correlation.",
        "related_metrics": ["mood_score"],
    },
}


def _match_condition_keys(conditions: List[str]) -> List[str]:
    hits: List[str] = []
    for raw in conditions or []:
        low = (raw or "").lower().strip()
        if not low:
            continue
        for k in _CONDITION_KB:
            if k in low and k not in hits:
                hits.append(k)
    return hits


def _build_condition_context(user: User, day_data, symptom_logs) -> Dict[str, Any]:
    conditions: List[str] = list(getattr(user, "medical_conditions", None) or [])
    allergies: List[str] = list(getattr(user, "allergies", None) or [])

    matched = _match_condition_keys(conditions)

    tips: List[Dict[str, Any]] = []
    watch: List[str] = []
    for key in matched:
        kb = _CONDITION_KB[key]
        for sym in kb["watch_symptoms"]:
            if sym not in watch:
                watch.append(sym)
        tips.append({
            "condition": kb["label"],
            "tip": kb["tip"],
            "watch": kb["watch_symptoms"],
        })

    # If the user has a condition, count how many of its watch symptoms
    # actually showed up in the last 30 days — so the client can render
    # a "3 of 5 migraine symptoms logged" banner.
    flagged_counts: Dict[str, int] = {}
    if matched and symptom_logs:
        logged_types = {
            (s.symptom_type or "").lower() for s in symptom_logs if s.symptom_type
        }
        for key in matched:
            kb = _CONDITION_KB[key]
            hits = sum(
                1 for s in kb["watch_symptoms"]
                if s.lower() in logged_types
            )
            flagged_counts[kb["label"]] = hits

    return {
        "conditions": conditions,
        "allergies": allergies,
        "matched_keys": matched,
        "watch_symptoms": watch,
        "tips": tips,
        "flagged_counts": flagged_counts,
    }


def _condition_recommendations(condition_ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    tips = condition_ctx.get("tips") or []
    out: List[Dict[str, Any]] = []
    for t in tips[:3]:
        out.append({
            "category": "health",
            "priority": "medium",
            "title": f"{t['condition']}: smart tip for you",
            "description": t["tip"],
            "icon": "health_and_safety",
            "deeplink": "/health/symptoms",
        })
    return out


#  14-DAY METRIC STREAMS

def _build_metric_streams(day_data, today, days=14):
    sleep, mood, study, focus, habits = [], [], [], [], []
    for i in range(days):
        d = today - timedelta(days=days - 1 - i)
        dd = day_data.get(d, _empty_day())
        sleep.append(dd["sleep_hours"] if dd["sleep_hours"] is not None else None)
        mood.append(dd["mood_score"] if (dd["mood_score"] or 0) > 0 else None)
        study.append(dd["study_minutes"] or 0)
        focus.append(round(dd["focus_avg"] or 0))
        if dd["habits_total"] > 0:
            habits.append(round(dd["habits_done"] / dd["habits_total"] * 100))
        else:
            habits.append(None)
    return {
        "sleep_hours": sleep,
        "mood_score": mood,
        "study_minutes": study,
        "focus_score": focus,
        "habit_pct": habits,
    }


def _build_wellness_history(day_data, today, days=14):
    out = []
    for i in range(days):
        d = today - timedelta(days=days - 1 - i)
        dd = day_data.get(d, _empty_day())
        components = []
        if dd["sleep_hours"] is not None:
            sleep_pts = max(0, 100 - abs(dd["sleep_hours"] - 8) * 14)
            components.append(sleep_pts)
        if (dd["mood_score"] or 0) > 0:
            components.append(dd["mood_score"] / 5 * 100)
        if dd["study_minutes"] > 0:
            components.append(min(100, dd["study_minutes"] / 60 * 50))
        if dd["habits_total"] > 0:
            components.append(dd["habits_done"] / dd["habits_total"] * 100)
        if components:
            out.append(round(_safe_mean(components)))
        else:
            out.append(None)
    return out


#  RHYTHMS — when do you actually thrive?

def _compute_rhythms(day_data, study_sessions, mood_entries, today,
                     synthetic: bool, user: User):
    # Weekday aggregates (Mon..Sun)
    weekday_buckets: Dict[int, Dict[str, List[float]]] = defaultdict(lambda: {
        "study": [], "mood": [], "sleep": [], "focus": [],
    })
    for d, dd in day_data.items():
        wd = d.weekday()
        if dd["study_minutes"] > 0:
            weekday_buckets[wd]["study"].append(dd["study_minutes"])
        if dd["mood_score"] > 0:
            weekday_buckets[wd]["mood"].append(dd["mood_score"])
        if dd["sleep_hours"] is not None:
            weekday_buckets[wd]["sleep"].append(dd["sleep_hours"])
        if dd["focus_avg"] > 0:
            weekday_buckets[wd]["focus"].append(dd["focus_avg"])

    by_weekday = []
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for wd in range(7):
        b = weekday_buckets[wd]
        by_weekday.append({
            "day": day_names[wd],
            "study_min": round(_safe_mean(b["study"])),
            "mood_score": round(_safe_mean(b["mood"]), 1),
            "sleep_hours": round(_safe_mean(b["sleep"]), 1),
            "focus": round(_safe_mean(b["focus"])),
        })

    # Hour-of-day study minutes (real sessions only — synthetic doesn't
    # carry hour data; fill with a deterministic curve when synthetic so
    # the chart isn't empty).
    by_hour = [0] * 24
    for s in study_sessions:
        if s.start_time and s.duration_minutes:
            by_hour[s.start_time.hour % 24] += s.duration_minutes
    if synthetic and sum(by_hour) == 0:
        seed_int = int(str(user.id).replace("-", "")[:8], 16)
        rng = random.Random(seed_int + 7)
        # Bias toward 9-11am and 7-10pm
        for h in range(24):
            base = 0
            if 9 <= h <= 11:
                base = 38
            elif 14 <= h <= 16:
                base = 22
            elif 19 <= h <= 22:
                base = 45
            elif 7 <= h <= 8:
                base = 18
            by_hour[h] = max(0, int(base + rng.uniform(-10, 12)))

    # Sleep–mood scatter (last 30 days — widened from 14 so the chart has
    # enough density to actually show a pattern even on sparse weeks).
    scatter = []
    for d, dd in day_data.items():
        if (today - d).days > 30:
            continue
        if dd["sleep_hours"] is not None and dd["mood_score"] > 0:
            scatter.append({
                "sleep": round(dd["sleep_hours"], 1),
                "mood": dd["mood_score"],
                "date": d.isoformat(),
            })

    # Best/worst day-of-week study identifiers (for headline-y chips)
    studied = [(b["day"], b["study_min"]) for b in by_weekday if b["study_min"] > 0]
    best_day = max(studied, key=lambda p: p[1])[0] if studied else None
    worst_day = min(studied, key=lambda p: p[1])[0] if len(studied) >= 2 else None

    hour_focus_buckets: Dict[int, List[float]] = defaultdict(list)
    for dd in day_data.values():
        for hr, _dur, focus in dd.get("session_hours", []):
            if focus and focus > 0:
                hour_focus_buckets[hr % 24].append(focus)
    by_hour_focus = [
        round(_safe_mean(hour_focus_buckets.get(h, []))) for h in range(24)
    ]

    # Best focus hour (only among hours with enough samples)
    qualifying = [
        (h, _safe_mean(v)) for h, v in hour_focus_buckets.items()
        if len(v) >= 2
    ]
    best_focus_hour = (
        max(qualifying, key=lambda p: p[1])[0] if qualifying else None
    )

    # Bedtime spread — std dev of bedtime hours
    bedtimes = [dd["bedtime_hour"] for dd in day_data.values()
                if dd.get("bedtime_hour") is not None]
    bedtime_spread = round(_std_dev(bedtimes), 2) if len(bedtimes) >= 3 else None
    bedtime_median = None
    if bedtimes:
        sorted_b = sorted(bedtimes)
        bedtime_median = round(sorted_b[len(sorted_b) // 2], 2)

    return {
        "by_weekday": by_weekday,
        "by_hour": by_hour,
        "by_hour_focus": by_hour_focus,
        "sleep_mood_scatter": scatter,
        "best_study_day": best_day,
        "lightest_study_day": worst_day,
        "best_hour": max(range(24), key=lambda h: by_hour[h]) if any(by_hour) else None,
        "best_focus_hour": best_focus_hour,
        "bedtime_spread_hours": bedtime_spread,
        "bedtime_median": bedtime_median,
    }


def _dominant_mood(day_data, since_date):
    moods = [dd["mood"] for d, dd in day_data.items()
             if d >= since_date and dd.get("mood")]
    if not moods:
        return None
    return Counter(moods).most_common(1)[0][0]
