from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from datetime import datetime, date, timedelta
from typing import List, Optional
from uuid import UUID

from app.database import get_db
from app.models.user import User
from app.models.daily import HabitEntry, HabitCompletion, ScheduleEntry
from app.models.gamification import XPTransaction
from app.utils.auth import get_current_user

router = APIRouter(prefix="/daily", tags=["daily"])

XP_PER_HABIT = 10
XP_PER_LEVEL = 500


@router.get("/habits")
def list_habits(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    habits = (
        db.query(HabitEntry)
        .filter(HabitEntry.user_id == current_user.id, HabitEntry.is_active == True)
        .order_by(HabitEntry.created_at)
        .all()
    )

    today = date.today()
    result = []
    for h in habits:
        completions_today = (
            db.query(HabitCompletion)
            .filter(
                HabitCompletion.habit_id == h.id,
                HabitCompletion.user_id == current_user.id,
                HabitCompletion.date == today,
            )
            .count()
        )
        result.append({
            "id": str(h.id),
            "name": h.name,
            "description": h.description,
            "icon": h.icon,
            "color": h.color,
            "frequency": h.frequency,
            "target_count": h.target_count,
            "streak_days": h.streak_days,
            "best_streak": h.best_streak,
            "xp_reward": h.xp_reward,
            "done": completions_today >= h.target_count,
            "completions_today": completions_today,
        })

    return result


@router.post("/habits", status_code=status.HTTP_201_CREATED)
def create_habit(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not data.get("name"):
        raise HTTPException(status_code=400, detail="Habit name is required")

    habit = HabitEntry(
        user_id=current_user.id,
        name=data["name"],
        description=data.get("description"),
        icon=data.get("icon", "check_circle"),
        color=data.get("color", "#10B981"),
        frequency=data.get("frequency", "daily"),
        target_count=data.get("target_count", 1),
        xp_reward=data.get("xp_reward", XP_PER_HABIT),
    )
    db.add(habit)
    db.commit()
    db.refresh(habit)

    return {
        "id": str(habit.id),
        "name": habit.name,
        "description": habit.description,
        "icon": habit.icon,
        "color": habit.color,
        "frequency": habit.frequency,
        "target_count": habit.target_count,
        "streak_days": habit.streak_days,
        "best_streak": habit.best_streak,
        "xp_reward": habit.xp_reward,
        "done": False,
        "completions_today": 0,
    }


@router.put("/habits/{habit_id}")
def update_habit(
    habit_id: UUID,
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    habit = (
        db.query(HabitEntry)
        .filter(HabitEntry.id == habit_id, HabitEntry.user_id == current_user.id)
        .first()
    )
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    updatable = ["name", "description", "icon", "color", "frequency", "target_count", "xp_reward"]
    for field in updatable:
        if field in data:
            setattr(habit, field, data[field])

    habit.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(habit)

    return {
        "id": str(habit.id),
        "name": habit.name,
        "description": habit.description,
        "icon": habit.icon,
        "color": habit.color,
        "frequency": habit.frequency,
        "target_count": habit.target_count,
        "streak_days": habit.streak_days,
        "best_streak": habit.best_streak,
        "xp_reward": habit.xp_reward,
    }


@router.delete("/habits/{habit_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_habit(
    habit_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    habit = (
        db.query(HabitEntry)
        .filter(HabitEntry.id == habit_id, HabitEntry.user_id == current_user.id)
        .first()
    )
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    habit.is_active = False
    habit.updated_at = datetime.utcnow()
    db.commit()
    return None


@router.post("/habits/{habit_id}/complete")
def toggle_habit_completion(
    habit_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    habit = (
        db.query(HabitEntry)
        .filter(HabitEntry.id == habit_id, HabitEntry.user_id == current_user.id)
        .first()
    )
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")

    today = date.today()
    existing = (
        db.query(HabitCompletion)
        .filter(
            HabitCompletion.habit_id == habit_id,
            HabitCompletion.user_id == current_user.id,
            HabitCompletion.date == today,
        )
        .first()
    )

    if existing:
        # undo completion
        db.delete(existing)
        habit.streak_days = max(0, habit.streak_days - 1)
        xp_change = -habit.xp_reward
        current_user.total_xp = max(0, current_user.total_xp + xp_change)
        current_user.level = max(1, current_user.total_xp // XP_PER_LEVEL + 1)
        done = False
    else:
        # mark complete
        completion = HabitCompletion(
            habit_id=habit_id,
            user_id=current_user.id,
            date=today,
        )
        db.add(completion)

        yesterday = today - timedelta(days=1)
        had_yesterday = (
            db.query(HabitCompletion)
            .filter(
                HabitCompletion.habit_id == habit_id,
                HabitCompletion.user_id == current_user.id,
                HabitCompletion.date == yesterday,
            )
            .count()
        ) > 0

        if had_yesterday:
            habit.streak_days += 1
        else:
            habit.streak_days = 1

        if habit.streak_days > habit.best_streak:
            habit.best_streak = habit.streak_days

        xp_change = habit.xp_reward
        current_user.total_xp += xp_change
        current_user.level = current_user.total_xp // XP_PER_LEVEL + 1

        xp_tx = XPTransaction(
            user_id=current_user.id,
            amount=xp_change,
            source="habit",
            description=f"Completed habit: {habit.name}",
            reference_id=str(habit.id),
        )
        db.add(xp_tx)
        done = True

    db.commit()
    db.refresh(habit)

    return {
        "id": str(habit.id),
        "name": habit.name,
        "icon": habit.icon,
        "done": done,
        "streak_days": habit.streak_days,
        "best_streak": habit.best_streak,
        "xp_awarded": xp_change,
        "total_xp": current_user.total_xp,
        "level": current_user.level,
    }


@router.get("/stats")
def daily_stats(
    target_date: Optional[str] = Query(None, description="YYYY-MM-DD, defaults to today"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if target_date:
        try:
            day = date.fromisoformat(target_date)
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")
    else:
        day = date.today()

    habits = (
        db.query(HabitEntry)
        .filter(HabitEntry.user_id == current_user.id, HabitEntry.is_active == True)
        .all()
    )

    habits_total = len(habits)
    habits_done = 0
    habit_details = []

    for h in habits:
        completed = (
            db.query(HabitCompletion)
            .filter(
                HabitCompletion.habit_id == h.id,
                HabitCompletion.user_id == current_user.id,
                HabitCompletion.date == day,
            )
            .count()
        )
        is_done = completed >= h.target_count
        if is_done:
            habits_done += 1
        habit_details.append({
            "id": str(h.id),
            "name": h.name,
            "icon": h.icon,
            "done": is_done,
            "streak_days": h.streak_days,
        })

    xp_today = (
        db.query(func.coalesce(func.sum(XPTransaction.amount), 0))
        .filter(
            XPTransaction.user_id == current_user.id,
            func.date(XPTransaction.created_at) == day,
        )
        .scalar()
    )

    user_streak = _calculate_user_streak(current_user.id, db)

    return {
        "date": day.isoformat(),
        "habits_done": habits_done,
        "habits_total": habits_total,
        "completion_pct": round(habits_done / habits_total * 100) if habits_total > 0 else 0,
        "habits": habit_details,
        "xp_earned_today": int(xp_today),
        "user_streak": user_streak,
        "total_xp": current_user.total_xp,
        "level": current_user.level,
        "coins": current_user.coins,
    }


@router.get("/history")
def habit_history(
    days: int = Query(7, ge=1, le=90, description="Number of days to look back"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    start = today - timedelta(days=days - 1)

    completions = (
        db.query(
            HabitCompletion.date,
            func.count(func.distinct(HabitCompletion.habit_id)).label("habits_done"),
        )
        .filter(
            HabitCompletion.user_id == current_user.id,
            HabitCompletion.date >= start,
            HabitCompletion.date <= today,
        )
        .group_by(HabitCompletion.date)
        .all()
    )

    total_habits = (
        db.query(HabitEntry)
        .filter(HabitEntry.user_id == current_user.id, HabitEntry.is_active == True)
        .count()
    )

    completion_map = {c.date: c.habits_done for c in completions}
    history = []
    for i in range(days):
        d = start + timedelta(days=i)
        done = completion_map.get(d, 0)
        history.append({
            "date": d.isoformat(),
            "habits_done": done,
            "habits_total": total_habits,
            "completion_pct": round(done / total_habits * 100) if total_habits > 0 else 0,
        })

    return {"days": days, "history": history}


@router.get("/schedule")
def get_schedule(
    start_date: Optional[str] = Query(None),
    end_date: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if start_date:
        start = datetime.fromisoformat(start_date)
    else:
        start = datetime.combine(date.today(), datetime.min.time())

    if end_date:
        end = datetime.fromisoformat(end_date)
    else:
        end = datetime.combine(date.today(), datetime.max.time())

    entries = (
        db.query(ScheduleEntry)
        .filter(
            ScheduleEntry.user_id == current_user.id,
            ScheduleEntry.start_time >= start,
            ScheduleEntry.start_time <= end,
        )
        .order_by(ScheduleEntry.start_time)
        .all()
    )

    return [
        {
            "id": str(e.id),
            "title": e.title,
            "description": e.description,
            "entry_type": e.entry_type,
            "start_time": e.start_time.isoformat() if e.start_time else None,
            "end_time": e.end_time.isoformat() if e.end_time else None,
            "location": e.location,
            "is_recurring": e.is_recurring,
            "color": e.color,
        }
        for e in entries
    ]


@router.post("/habits/seed-defaults")
def seed_default_habits(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing = (
        db.query(HabitEntry)
        .filter(HabitEntry.user_id == current_user.id)
        .count()
    )
    if existing > 0:
        return {"message": "User already has habits", "created": 0}

    defaults = [
        {"name": "Drink Water", "icon": "water", "color": "#3B82F6"},
        {"name": "Read 15 min", "icon": "book", "color": "#8B5CF6"},
        {"name": "Exercise", "icon": "fitness", "color": "#EF4444"},
        {"name": "Stretch", "icon": "fitness", "color": "#10B981"},
    ]

    created = []
    for d in defaults:
        habit = HabitEntry(
            user_id=current_user.id,
            name=d["name"],
            icon=d["icon"],
            color=d["color"],
            xp_reward=XP_PER_HABIT,
        )
        db.add(habit)
        created.append(d["name"])

    db.commit()
    return {"message": f"Created {len(created)} default habits", "created": len(created), "habits": created}


def _calculate_user_streak(user_id, db: Session) -> int:
    today = date.today()
    streak = 0
    check_date = today

    for _ in range(365):
        count = (
            db.query(HabitCompletion)
            .filter(
                HabitCompletion.user_id == user_id,
                HabitCompletion.date == check_date,
            )
            .count()
        )
        if count > 0:
            streak += 1
            check_date -= timedelta(days=1)
        else:
            break

    return streak
