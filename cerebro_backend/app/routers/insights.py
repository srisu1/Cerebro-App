from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import datetime, date, timedelta, timezone
from decimal import Decimal
from collections import defaultdict
from typing import List, Dict, Any, Optional

from app.database import get_db
from app.models.user import User
from app.models.study import Subject, StudySession, Quiz, Flashcard
from app.models.health import SleepLog, MoodEntry, MoodDefinition, MedicationLog, WaterLog, SymptomLog
from app.models.daily import HabitEntry, HabitCompletion
from app.models.gamification import XPTransaction
from app.utils.auth import get_current_user

router = APIRouter(prefix="/insights", tags=["insights"])


def _safe_mean(values: list) -> float:
    return sum(values) / len(values) if values else 0.0


def _aware(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


@router.get("/dashboard")
def get_insights_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_id = current_user.id
    now = datetime.now(timezone.utc)
    today = date.today()
    week_ago = today - timedelta(days=7)
    month_ago = today - timedelta(days=30)

    # fetch raw data (last 30 days)
    sleep_logs = (
        db.query(SleepLog)
        .filter(SleepLog.user_id == user_id, SleepLog.date >= month_ago)
        .order_by(SleepLog.date)
        .all()
    )
    mood_entries = (
        db.query(MoodEntry)
        .filter(MoodEntry.user_id == user_id, MoodEntry.created_at >= _aware(datetime.combine(month_ago, datetime.min.time())))
        .order_by(MoodEntry.created_at)
        .all()
    )

    mood_defs = db.query(MoodDefinition).all()
    mood_id_to_name = {str(md.id): md.name.lower() for md in mood_defs}
    study_sessions = (
        db.query(StudySession)
        .filter(StudySession.user_id == user_id, StudySession.start_time >= _aware(datetime.combine(month_ago, datetime.min.time())))
        .all()
    )
    habit_completions = (
        db.query(HabitCompletion)
        .filter(HabitCompletion.user_id == user_id, HabitCompletion.date >= month_ago)
        .all()
    )
    water_logs = (
        db.query(WaterLog)
        .filter(WaterLog.user_id == user_id, WaterLog.date >= month_ago)
        .all()
    )

    # per-day aggregates
    day_data: Dict[date, Dict[str, Any]] = defaultdict(lambda: {
        "sleep_hours": None, "sleep_quality": None,
        "mood": None, "mood_score": 0,
        "study_minutes": 0, "focus_avg": 0, "focus_scores": [],
        "habits_done": 0, "habits_total": 0,
        "water_ml": 0,
    })

    MOOD_SCORES = {
        "happy": 5, "excited": 5, "grateful": 4, "calm": 4,
        "focused": 3, "playful": 3,
        "tired": 2, "sleepy": 2, "anxious": 2,
        "sad": 1, "angry": 1,
    }

    for sl in sleep_logs:
        d = sl.date
        day_data[d]["sleep_hours"] = float(sl.total_hours) if sl.total_hours else None
        day_data[d]["sleep_quality"] = sl.quality_rating

    for me in mood_entries:
        d = me.created_at.date() if me.created_at else today
        mood_name = mood_id_to_name.get(str(me.mood_id), "calm")
        day_data[d]["mood"] = mood_name
        day_data[d]["mood_score"] = MOOD_SCORES.get(mood_name, 3)

    for ss in study_sessions:
        if ss.start_time:
            d = ss.start_time.date()
            day_data[d]["study_minutes"] += (ss.duration_minutes or 0)
            if ss.focus_score and ss.focus_score > 0:
                day_data[d]["focus_scores"].append(ss.focus_score)

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
        day_data[wl.date]["water_ml"] += (wl.amount_ml or 0)

    for d in day_data:
        scores = day_data[d]["focus_scores"]
        day_data[d]["focus_avg"] = _safe_mean(scores) if scores else 0

    # wellness score
    wellness = _compute_wellness_score(day_data, week_ago, today, current_user)

    # correlations
    correlations = _compute_correlations(day_data)

    # pattern detection
    patterns = _detect_patterns(day_data, sleep_logs, mood_entries, study_sessions)

    # recommendations
    recommendations = _generate_recommendations(
        wellness, correlations, patterns, day_data, current_user
    )

    # weekly overview (last 7 days)
    weekly = []
    for i in range(7):
        d = week_ago + timedelta(days=i)
        dd = day_data.get(d, {})
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

    # domain summaries
    recent_days = [d for d in day_data if d >= week_ago]

    study_summary = {
        "total_minutes_week": sum(day_data[d]["study_minutes"] for d in recent_days),
        "avg_focus": round(_safe_mean([day_data[d]["focus_avg"] for d in recent_days if day_data[d]["focus_avg"] > 0])),
        "sessions_count": len([s for s in study_sessions if s.start_time and s.start_time.date() >= week_ago]),
    }

    sleep_summary = {
        "avg_hours": round(_safe_mean([day_data[d]["sleep_hours"] for d in recent_days if day_data[d]["sleep_hours"] is not None]), 1),
        "nights_logged": len([d for d in recent_days if day_data[d]["sleep_hours"] is not None]),
    }

    mood_summary = {
        "avg_score": round(_safe_mean([day_data[d]["mood_score"] for d in recent_days if day_data[d]["mood_score"] > 0]), 1),
        "dominant_mood": _dominant_mood(mood_entries, week_ago, mood_id_to_name),
    }

    habit_summary = {
        "avg_completion_pct": round(_safe_mean([
            (day_data[d]["habits_done"] / day_data[d]["habits_total"] * 100)
            if day_data[d]["habits_total"] > 0 else 0
            for d in recent_days
        ])),
    }

    return {
        "wellness_score": wellness["score"],
        "wellness_breakdown": wellness["breakdown"],
        "wellness_trend": wellness["trend"],
        "correlations": correlations,
        "patterns": patterns,
        "recommendations": recommendations,
        "weekly_overview": weekly,
        "study_summary": study_summary,
        "sleep_summary": sleep_summary,
        "mood_summary": mood_summary,
        "habit_summary": habit_summary,
        "total_xp": current_user.total_xp,
        "level": current_user.level,
        "streak_days": current_user.streak_days,
    }


def _compute_wellness_score(day_data, week_ago, today, user):
    recent_days = [d for d in day_data if d >= week_ago]

    # sleep component (0-25)
    sleep_hours = [day_data[d]["sleep_hours"] for d in recent_days if day_data[d]["sleep_hours"] is not None]
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

    # mood component (0-25)
    mood_scores = [day_data[d]["mood_score"] for d in recent_days if day_data[d]["mood_score"] > 0]
    if mood_scores:
        avg_mood = _safe_mean(mood_scores)
        mood_score = round(avg_mood / 5 * 25)
    else:
        mood_score = 12

    # study component (0-25)
    study_days = [d for d in recent_days if day_data[d]["study_minutes"] > 0]
    study_consistency = len(study_days) / max(len(recent_days), 1)
    focus_vals = [day_data[d]["focus_avg"] for d in recent_days if day_data[d]["focus_avg"] > 0]
    avg_focus = _safe_mean(focus_vals) if focus_vals else 50
    study_score = round((study_consistency * 12.5) + (avg_focus / 100 * 12.5))

    # habits component (0-25)
    habit_pcts = []
    for d in recent_days:
        if day_data[d]["habits_total"] > 0:
            habit_pcts.append(day_data[d]["habits_done"] / day_data[d]["habits_total"])
    if habit_pcts:
        habit_score = round(_safe_mean(habit_pcts) * 25)
    else:
        habit_score = 10

    total = min(100, sleep_score + mood_score + study_score + habit_score)

    # trend (compare this week vs previous week)
    prev_week = [d for d in day_data if week_ago - timedelta(days=7) <= d < week_ago]
    if prev_week and recent_days:
        prev_avg_mood = _safe_mean([day_data[d]["mood_score"] for d in prev_week if day_data[d]["mood_score"] > 0]) or 3
        curr_avg_mood = _safe_mean([day_data[d]["mood_score"] for d in recent_days if day_data[d]["mood_score"] > 0]) or 3
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
            "sleep": sleep_score,
            "mood": mood_score,
            "study": study_score,
            "habits": habit_score,
        },
        "trend": trend,
    }


def _compute_correlations(day_data):
    correlations = []

    # sleep vs study focus
    paired_sleep_focus = [
        (day_data[d]["sleep_hours"], day_data[d]["focus_avg"])
        for d in day_data
        if day_data[d]["sleep_hours"] is not None and day_data[d]["focus_avg"] > 0
    ]
    if len(paired_sleep_focus) >= 3:
        sleep_vals = [p[0] for p in paired_sleep_focus]
        focus_vals = [p[1] for p in paired_sleep_focus]
        corr = _pearson(sleep_vals, focus_vals)
        strength = _correlation_strength(corr)
        correlations.append({
            "type": "sleep_focus",
            "label": "Sleep vs Study Focus",
            "correlation": round(corr, 2),
            "strength": strength,
            "insight": _sleep_focus_insight(corr, _safe_mean(sleep_vals)),
            "icon": "bedtime",
        })

    # mood vs study minutes
    paired_mood_study = [
        (day_data[d]["mood_score"], day_data[d]["study_minutes"])
        for d in day_data
        if day_data[d]["mood_score"] > 0 and day_data[d]["study_minutes"] > 0
    ]
    if len(paired_mood_study) >= 3:
        mood_vals = [p[0] for p in paired_mood_study]
        study_vals = [p[1] for p in paired_mood_study]
        corr = _pearson(mood_vals, study_vals)
        strength = _correlation_strength(corr)
        correlations.append({
            "type": "mood_study",
            "label": "Mood vs Study Time",
            "correlation": round(corr, 2),
            "strength": strength,
            "insight": _mood_study_insight(corr),
            "icon": "mood",
        })

    # sleep vs mood
    paired_sleep_mood = [
        (day_data[d]["sleep_hours"], day_data[d]["mood_score"])
        for d in day_data
        if day_data[d]["sleep_hours"] is not None and day_data[d]["mood_score"] > 0
    ]
    if len(paired_sleep_mood) >= 3:
        s_vals = [p[0] for p in paired_sleep_mood]
        m_vals = [p[1] for p in paired_sleep_mood]
        corr = _pearson(s_vals, m_vals)
        strength = _correlation_strength(corr)
        correlations.append({
            "type": "sleep_mood",
            "label": "Sleep vs Mood",
            "correlation": round(corr, 2),
            "strength": strength,
            "insight": _sleep_mood_insight(corr),
            "icon": "nights_stay",
        })

    # habits vs mood
    paired_habit_mood = [
        (day_data[d]["habits_done"] / max(day_data[d]["habits_total"], 1), day_data[d]["mood_score"])
        for d in day_data
        if day_data[d]["habits_total"] > 0 and day_data[d]["mood_score"] > 0
    ]
    if len(paired_habit_mood) >= 3:
        h_vals = [p[0] for p in paired_habit_mood]
        m_vals = [p[1] for p in paired_habit_mood]
        corr = _pearson(h_vals, m_vals)
        strength = _correlation_strength(corr)
        correlations.append({
            "type": "habits_mood",
            "label": "Habits vs Mood",
            "correlation": round(corr, 2),
            "strength": strength,
            "insight": _habits_mood_insight(corr),
            "icon": "check_circle",
        })

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
    elif ar >= 0.4:
        return "moderate"
    elif ar >= 0.2:
        return "weak"
    return "negligible"


def _sleep_focus_insight(corr, avg_sleep):
    if corr > 0.4:
        return f"Better sleep strongly correlates with higher focus. Your avg is {avg_sleep:.1f}h — aim for 7-9h."
    elif corr > 0.2:
        return "There's a mild link between your sleep and focus. More data will sharpen this."
    elif corr < -0.2:
        return "Interestingly, more sleep doesn't always mean better focus for you. Quality over quantity?"
    return "No clear pattern yet between your sleep and focus."


def _mood_study_insight(corr):
    if corr > 0.4:
        return "You study more on days you feel good. Leverage your mood — study harder on great days."
    elif corr > 0.2:
        return "Positive mood slightly boosts study time. Keep logging to reveal the full pattern."
    elif corr < -0.2:
        return "You might study as a coping mechanism on tough days — that's actually useful!"
    return "Your study habits seem independent of mood — that's disciplined."


def _sleep_mood_insight(corr):
    if corr > 0.4:
        return "Sleep strongly affects your mood. Prioritize consistent bedtimes."
    elif corr > 0.2:
        return "Better sleep tends to lift your mood slightly."
    return "Your mood seems fairly independent of sleep duration."


def _habits_mood_insight(corr):
    if corr > 0.4:
        return "Completing habits significantly boosts your mood. Keep the streaks going!"
    elif corr > 0.2:
        return "Habit completion gives you a mild mood lift."
    return "Your mood doesn't seem tied to habit completion — that's fine, habits build discipline either way."


def _detect_patterns(day_data, sleep_logs, mood_entries, study_sessions):
    patterns = []

    # best study day of the week
    day_minutes: Dict[str, List[int]] = defaultdict(list)
    for d, dd in day_data.items():
        if dd["study_minutes"] > 0:
            day_minutes[d.strftime("%A")].append(dd["study_minutes"])
    if day_minutes:
        best_day = max(day_minutes, key=lambda k: _safe_mean(day_minutes[k]))
        avg_mins = round(_safe_mean(day_minutes[best_day]))
        patterns.append({
            "type": "best_study_day",
            "title": "Peak Study Day",
            "description": f"You study most on {best_day}s — averaging {avg_mins} min.",
            "icon": "trending_up",
            "severity": "positive",
        })

    # sleep consistency
    sleep_hours_list = [float(sl.total_hours) for sl in sleep_logs if sl.total_hours]
    if len(sleep_hours_list) >= 5:
        std_dev = _std_dev(sleep_hours_list)
        if std_dev < 0.8:
            patterns.append({
                "type": "sleep_consistent",
                "title": "Consistent Sleeper",
                "description": f"Your sleep varies by only {std_dev:.1f}h — great consistency!",
                "icon": "hotel",
                "severity": "positive",
            })
        elif std_dev > 1.5:
            patterns.append({
                "type": "sleep_irregular",
                "title": "Irregular Sleep",
                "description": f"Your sleep varies by {std_dev:.1f}h — try a consistent bedtime.",
                "icon": "warning",
                "severity": "warning",
            })

    # late night study detection
    late_sessions = [
        s for s in study_sessions
        if s.start_time and s.start_time.hour >= 22
    ]
    if len(late_sessions) >= 3:
        patterns.append({
            "type": "night_owl",
            "title": "Night Owl Alert",
            "description": f"You've had {len(late_sessions)} late-night study sessions. Consider earlier sessions for better retention.",
            "icon": "dark_mode",
            "severity": "info",
        })

    # mood stability
    mood_scores = [dd["mood_score"] for dd in day_data.values() if dd["mood_score"] > 0]
    if len(mood_scores) >= 5:
        mood_std = _std_dev(mood_scores)
        if mood_std < 0.8:
            patterns.append({
                "type": "stable_mood",
                "title": "Emotionally Steady",
                "description": "Your mood has been stable — that's great for sustained productivity.",
                "icon": "sentiment_satisfied",
                "severity": "positive",
            })
        elif mood_std > 1.5:
            patterns.append({
                "type": "mood_volatile",
                "title": "Mood Swings Detected",
                "description": "Your mood fluctuates significantly. Consider journaling or exercise as regulators.",
                "icon": "swap_vert",
                "severity": "warning",
            })

    # habit streak recognition
    habit_completion_streak = 0
    today = date.today()
    for i in range(30):
        d = today - timedelta(days=i)
        dd = day_data.get(d, {})
        if dd.get("habits_done", 0) > 0:
            habit_completion_streak += 1
        else:
            break

    if habit_completion_streak >= 7:
        patterns.append({
            "type": "habit_streak",
            "title": f"{habit_completion_streak}-Day Habit Streak!",
            "description": f"You've completed habits for {habit_completion_streak} days straight. Impressive discipline!",
            "icon": "local_fire_department",
            "severity": "positive",
        })

    return patterns


def _std_dev(values: List[float]) -> float:
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    return variance ** 0.5


def _generate_recommendations(wellness, correlations, patterns, day_data, user):
    recs = []

    score = wellness["score"]
    breakdown = wellness["breakdown"]

    if breakdown["sleep"] < 15:
        recs.append({
            "category": "sleep",
            "priority": "high",
            "title": "Improve Your Sleep",
            "description": "Your sleep score is low. Aim for 7-9 hours consistently and keep a regular bedtime.",
            "icon": "bedtime",
        })

    if breakdown["mood"] < 12:
        recs.append({
            "category": "mood",
            "priority": "medium",
            "title": "Mood Check-In",
            "description": "Your mood has been lower than usual. Consider activities you enjoy, exercise, or talking to someone.",
            "icon": "mood",
        })

    if breakdown["study"] < 12:
        recs.append({
            "category": "study",
            "priority": "high",
            "title": "Study Consistency",
            "description": "Your study regularity is below average. Even 25-minute Pomodoro sessions daily can make a big difference.",
            "icon": "school",
        })

    if breakdown["habits"] < 12:
        recs.append({
            "category": "habits",
            "priority": "medium",
            "title": "Build Habit Momentum",
            "description": "Try completing at least one habit per day to start building momentum.",
            "icon": "check_circle",
        })

    for corr in correlations:
        if corr["type"] == "sleep_focus" and corr["correlation"] > 0.4:
            recs.append({
                "category": "cross_domain",
                "priority": "high",
                "title": "Sleep = Better Focus",
                "description": f"Your data shows a {corr['strength']} link between sleep and study focus. Prioritize rest before big study days.",
                "icon": "insights",
            })

    if user.streak_days >= 3:
        recs.append({
            "category": "motivation",
            "priority": "low",
            "title": f"Keep the {user.streak_days}-Day Streak!",
            "description": "You're building great momentum. Don't break the chain!",
            "icon": "local_fire_department",
        })

    if score >= 80:
        recs.append({
            "category": "celebration",
            "priority": "low",
            "title": "You're Crushing It!",
            "description": f"Wellness score of {score}/100 — you're in great shape across all domains.",
            "icon": "emoji_events",
        })

    return recs[:6]


def _dominant_mood(mood_entries, since_date, mood_id_to_name=None):
    if mood_id_to_name is None:
        mood_id_to_name = {}
    moods = [
        mood_id_to_name.get(str(me.mood_id), "unknown")
        for me in mood_entries
        if me.created_at and me.created_at.date() >= since_date
    ]
    if not moods:
        return None
    from collections import Counter
    return Counter(moods).most_common(1)[0][0]
