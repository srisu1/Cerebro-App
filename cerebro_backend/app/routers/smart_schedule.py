from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from pydantic import BaseModel
from datetime import datetime, timedelta, timezone, date, time
from typing import Optional, List, Dict, Tuple
from collections import defaultdict
import uuid

from app.database import get_db
from app.models.user import User
from app.models.calendar import StudyEvent, GoogleCalendarToken
from app.models.smart_schedule import SmartScheduleConfig
from app.models.study import Subject, StudySession, Flashcard, FlashcardDeck, Quiz
from app.models.quiz_engine import QuizSchedule
from app.utils.auth import get_current_user

# Reuse existing GCal helpers — we don't re-implement OAuth here.
from app.routers.calendar import (
    _get_valid_token, _try_gcal_push, _pull_events_from_gcal,  # noqa: F401
)

router = APIRouter(prefix="/study/smart-schedule", tags=["smart-schedule"])


#  SCHEMAS

class ConfigPayload(BaseModel):
    enable_focus_sessions: Optional[bool] = None
    enable_flashcards: Optional[bool] = None
    enable_quizzes: Optional[bool] = None
    enable_light_review: Optional[bool] = None

    focus_sessions_per_week: Optional[int] = None
    focus_session_minutes: Optional[int] = None
    flashcard_blocks_per_week: Optional[int] = None
    flashcard_block_minutes: Optional[int] = None
    quiz_blocks_per_week: Optional[int] = None
    quiz_block_minutes: Optional[int] = None
    light_review_blocks_per_week: Optional[int] = None
    light_review_minutes: Optional[int] = None

    preferred_start_hour: Optional[int] = None
    preferred_end_hour: Optional[int] = None
    avoid_weekends: Optional[bool] = None

    respect_google_calendar: Optional[bool] = None
    min_gap_minutes: Optional[int] = None

    enabled: Optional[bool] = None


class BlockPayload(BaseModel):
    title: str
    activity_type: str            # focus, flashcard, quiz, light_review
    start_time: datetime
    end_time: datetime
    subject_id: Optional[str] = None
    subject_name: Optional[str] = None
    subject_color: Optional[str] = None
    topic: Optional[str] = None
    reason: Optional[str] = None


class CommitPayload(BaseModel):
    blocks: List[BlockPayload]
    push_to_gcal: bool = True


#  CONFIG ENDPOINTS

def _ensure_config(user: User, db: Session) -> SmartScheduleConfig:
    cfg = db.query(SmartScheduleConfig).filter(
        SmartScheduleConfig.user_id == user.id
    ).first()
    if cfg is None:
        cfg = SmartScheduleConfig(user_id=user.id)
        db.add(cfg)
        db.commit()
        db.refresh(cfg)
    return cfg


def _config_to_dict(c: SmartScheduleConfig) -> dict:
    return {
        "enable_focus_sessions": c.enable_focus_sessions,
        "enable_flashcards": c.enable_flashcards,
        "enable_quizzes": c.enable_quizzes,
        "enable_light_review": c.enable_light_review,
        "focus_sessions_per_week": c.focus_sessions_per_week,
        "focus_session_minutes": c.focus_session_minutes,
        "flashcard_blocks_per_week": c.flashcard_blocks_per_week,
        "flashcard_block_minutes": c.flashcard_block_minutes,
        "quiz_blocks_per_week": c.quiz_blocks_per_week,
        "quiz_block_minutes": c.quiz_block_minutes,
        "light_review_blocks_per_week": c.light_review_blocks_per_week,
        "light_review_minutes": c.light_review_minutes,
        "preferred_start_hour": c.preferred_start_hour,
        "preferred_end_hour": c.preferred_end_hour,
        "avoid_weekends": c.avoid_weekends,
        "respect_google_calendar": c.respect_google_calendar,
        "min_gap_minutes": c.min_gap_minutes,
        "enabled": c.enabled,
        "last_plan_generated_at": c.last_plan_generated_at.isoformat() if c.last_plan_generated_at else None,
        "last_plan_committed_at": c.last_plan_committed_at.isoformat() if c.last_plan_committed_at else None,
    }


@router.get("/config")
def get_config(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cfg = _ensure_config(current_user, db)
    return _config_to_dict(cfg)


@router.post("/config")
def update_config(
    body: ConfigPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cfg = _ensure_config(current_user, db)
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is not None:
            setattr(cfg, k, v)
    db.commit()
    db.refresh(cfg)
    return _config_to_dict(cfg)


#  ENGINE — PEAK FOCUS + CONFLICTS + NEEDS

def _peak_focus_profile(user: User, db: Session) -> List[float]:
    cutoff = datetime.utcnow() - timedelta(days=30)
    sessions = db.query(StudySession).filter(
        StudySession.user_id == user.id,
        StudySession.start_time >= cutoff,
        StudySession.focus_score.isnot(None),
    ).all()

    buckets: Dict[int, List[int]] = defaultdict(list)
    for s in sessions:
        if s.focus_score and s.start_time:
            buckets[s.start_time.hour].append(int(s.focus_score))

    enough_data = sum(len(v) for v in buckets.values()) >= 6

    if enough_data:
        profile = [
            (sum(buckets[h]) / len(buckets[h])) if buckets.get(h) else 0.0
            for h in range(24)
        ]
        # Smooth zero-sample hours by interpolating neighbors so the greedy
        # picker doesn't pathologically avoid hours we simply haven't tested.
        filled = profile[:]
        for h in range(24):
            if profile[h] == 0.0:
                left = next((profile[i] for i in range(h - 1, -1, -1) if profile[i] > 0), None)
                right = next((profile[i] for i in range(h + 1, 24) if profile[i] > 0), None)
                if left is not None and right is not None:
                    filled[h] = (left + right) / 2.0 * 0.85   # penalty for unknown
                elif left is not None:
                    filled[h] = left * 0.8
                elif right is not None:
                    filled[h] = right * 0.8
                else:
                    filled[h] = 50.0
        return filled

    # Fallback curve: mid-morning + mid-afternoon peaks, low at night.
    default = [
        20, 15, 10, 10, 10, 15,      # 00–05
        25, 40, 55, 70, 80, 75,      # 06–11
        60, 55, 70, 75, 70, 60,      # 12–17
        55, 50, 45, 40, 30, 25,      # 18–23
    ]
    return [float(v) for v in default]


def _collect_conflicts(
    user: User, db: Session, cfg: SmartScheduleConfig,
    horizon_start: datetime, horizon_end: datetime,
) -> List[Tuple[datetime, datetime, str]]:
    conflicts: List[Tuple[datetime, datetime, str]] = []

    # 1) Local StudyEvents
    local = db.query(StudyEvent).filter(
        StudyEvent.user_id == user.id,
        StudyEvent.end_time >= horizon_start,
        StudyEvent.start_time <= horizon_end,
    ).all()
    for e in local:
        if e.start_time and e.end_time:
            conflicts.append((
                _as_utc(e.start_time),
                _as_utc(e.end_time),
                f"local:{e.event_type}",
            ))

    # 2) Google Calendar — pull-with-import so they land in StudyEvent too.
    if cfg.respect_google_calendar:
        token = _get_valid_token(user, db)
        if token:
            try:
                # The pull helper creates gcal_import StudyEvents, which the
                # query above will pick up next time — but we also add them
                # to conflicts right now so this preview reflects today's GCal.
                _pull_events_from_gcal(token, user, db)
                refreshed = db.query(StudyEvent).filter(
                    StudyEvent.user_id == user.id,
                    StudyEvent.source == "gcal_import",
                    StudyEvent.end_time >= horizon_start,
                    StudyEvent.start_time <= horizon_end,
                ).all()
                seen = {(c[0], c[1]) for c in conflicts}
                for e in refreshed:
                    key = (_as_utc(e.start_time), _as_utc(e.end_time))
                    if key not in seen and e.start_time and e.end_time:
                        conflicts.append((key[0], key[1], "gcal"))
            except Exception as ex:
                # Non-fatal — if GCal pull fails we still return local conflicts.
                print(f"[SMART-SCHED] GCal pull failed: {ex}")

    return conflicts


def _as_utc(dt: datetime) -> datetime:
    if dt is None:
        return dt
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def _build_need_pool(
    user: User, db: Session, cfg: SmartScheduleConfig,
) -> Dict[str, List[dict]]:
    pool: Dict[str, List[dict]] = {
        "focus": [], "flashcard": [], "quiz": [], "light_review": [],
    }

    subjects = db.query(Subject).filter(Subject.user_id == user.id).all()

    if cfg.enable_focus_sessions and subjects:
        # Rank subjects by "need" = gap between target and current proficiency,
        # with a boost for subjects that haven't been studied in the last 7 days.
        recent_cutoff = datetime.utcnow() - timedelta(days=7)
        recent_by_subject = {
            row[0]: row[1] for row in db.query(
                StudySession.subject_id, func.max(StudySession.start_time)
            ).filter(
                StudySession.user_id == user.id,
                StudySession.start_time >= recent_cutoff,
            ).group_by(StudySession.subject_id).all()
        }
        ranked = sorted(subjects, key=lambda s: (
            -(float(s.target_proficiency or 100) - float(s.current_proficiency or 0)),
            recent_by_subject.get(s.id, datetime.min.replace(tzinfo=timezone.utc))
            if recent_by_subject.get(s.id) else datetime.min.replace(tzinfo=timezone.utc),
        ))
        # Cycle through weakest subjects up to 2x the quota so we have slack.
        for i, subj in enumerate(ranked[:max(1, cfg.focus_sessions_per_week * 2)]):
            gap = float(subj.target_proficiency or 100) - float(subj.current_proficiency or 0)
            last = recent_by_subject.get(subj.id)
            need = 40 + min(60, max(0, gap))
            if not last:
                need += 15
            reason = f"Weakest gap — {gap:.0f} pts to target" if gap > 5 \
                     else f"Haven't studied {subj.name} in a while" if not last \
                     else f"Keep {subj.name} sharp"
            pool["focus"].append({
                "activity_type": "focus",
                "title": f"Focus — {subj.name}",
                "subject_id": str(subj.id),
                "subject_name": subj.name,
                "subject_color": subj.color or "#9DD4F0",
                "topic": None,
                "need_score": need,
                "duration_minutes": cfg.focus_session_minutes,
                "reason": reason,
            })

    if cfg.enable_flashcards:
        today = date.today()
        due = db.query(
            Flashcard.deck_id, func.count(Flashcard.id), func.min(Flashcard.next_review_date)
        ).filter(
            Flashcard.user_id == user.id,
            Flashcard.next_review_date <= today,
            Flashcard.deck_id.isnot(None),
        ).group_by(Flashcard.deck_id).all()

        for deck_id, count, earliest in due:
            if not deck_id:
                continue
            deck = db.query(FlashcardDeck).filter(FlashcardDeck.id == deck_id).first()
            if not deck:
                continue
            days_overdue = (today - earliest).days if earliest else 0
            need = 45 + min(40, count * 2) + min(15, days_overdue * 3)
            reason = f"{count} cards due" if days_overdue <= 0 \
                     else f"{count} cards due — {days_overdue}d overdue"
            pool["flashcard"].append({
                "activity_type": "flashcard",
                "title": f"Review — {deck.name}",
                "subject_id": str(deck.subject_id) if deck.subject_id else None,
                "subject_name": deck.name,
                "subject_color": deck.color or "#A8D5A3",
                "topic": None,
                "need_score": need,
                "duration_minutes": cfg.flashcard_block_minutes,
                "reason": reason,
            })

    if cfg.enable_quizzes:
        qsched = db.query(QuizSchedule).filter(
            QuizSchedule.user_id == user.id,
            QuizSchedule.enabled == True,  # noqa: E712
        ).first()
        if qsched and qsched.next_due_at:
            days_to_due = (_as_utc(qsched.next_due_at) - datetime.now(timezone.utc)).days
            need = 70 if days_to_due <= 0 else max(30, 70 - days_to_due * 5)
            pool["quiz"].append({
                "activity_type": "quiz",
                "title": "Scheduled Quiz",
                "subject_id": None,
                "subject_name": "Quiz",
                "subject_color": "#F4A261",
                "topic": None,
                "need_score": need,
                "duration_minutes": cfg.quiz_block_minutes,
                "reason": "Due this week" if days_to_due <= 7 else "Upcoming scheduled quiz",
            })

        # One quiz per subject that hasn't been quizzed in 10+ days
        recent_cutoff = date.today() - timedelta(days=10)
        recent_quizzes = {
            row[0]: row[1] for row in db.query(
                Quiz.subject_id, func.max(Quiz.date_taken)
            ).filter(
                Quiz.user_id == user.id
            ).group_by(Quiz.subject_id).all()
        }
        for subj in subjects:
            last_q = recent_quizzes.get(subj.id)
            if last_q is None or last_q <= recent_cutoff:
                pool["quiz"].append({
                    "activity_type": "quiz",
                    "title": f"Quiz — {subj.name}",
                    "subject_id": str(subj.id),
                    "subject_name": subj.name,
                    "subject_color": subj.color or "#F4A261",
                    "topic": None,
                    "need_score": 50 if last_q else 55,
                    "duration_minutes": cfg.quiz_block_minutes,
                    "reason": "No recent quiz — test recall" if last_q
                              else "Never been quizzed — establish baseline",
                })

    if cfg.enable_light_review and subjects:
        recent_cutoff = datetime.utcnow() - timedelta(days=3)
        recent_sessions = db.query(StudySession).filter(
            StudySession.user_id == user.id,
            StudySession.start_time >= recent_cutoff,
            StudySession.subject_id.isnot(None),
        ).order_by(StudySession.start_time.desc()).limit(10).all()
        seen_subj_ids = set()
        for s in recent_sessions:
            if s.subject_id in seen_subj_ids:
                continue
            seen_subj_ids.add(s.subject_id)
            subj = next((sub for sub in subjects if sub.id == s.subject_id), None)
            if not subj:
                continue
            topic = (s.topics_covered or [None])[0] if s.topics_covered else None
            pool["light_review"].append({
                "activity_type": "light_review",
                "title": f"Light review — {subj.name}",
                "subject_id": str(subj.id),
                "subject_name": subj.name,
                "subject_color": subj.color or "#C9B1FF",
                "topic": topic,
                "need_score": 30,
                "duration_minutes": cfg.light_review_minutes,
                "reason": f"Reinforce {'today' if (datetime.utcnow() - _as_utc(s.start_time).replace(tzinfo=None)).days == 0 else 'recent'} session",
            })

    for key in pool:
        pool[key].sort(key=lambda x: -x["need_score"])
    return pool


#  SLOT GENERATION + GREEDY PACKER

SLOT_MINUTES = 30  # grid resolution


def _iter_slots(
    horizon_start: datetime, horizon_end: datetime,
    cfg: SmartScheduleConfig,
) -> List[datetime]:
    out: List[datetime] = []
    cur = horizon_start.replace(minute=(horizon_start.minute // SLOT_MINUTES) * SLOT_MINUTES,
                                second=0, microsecond=0)
    if cur < horizon_start:
        cur += timedelta(minutes=SLOT_MINUTES)
    while cur < horizon_end:
        h = cur.hour
        weekday = cur.weekday()  # Mon=0, Sun=6
        weekend = weekday >= 5
        if (cfg.preferred_start_hour <= h < cfg.preferred_end_hour
                and not (cfg.avoid_weekends and weekend)):
            out.append(cur)
        cur += timedelta(minutes=SLOT_MINUTES)
    return out


def _slot_free(
    slot_start: datetime, duration_minutes: int,
    busy: List[Tuple[datetime, datetime, str]],
    proposed: List[Tuple[datetime, datetime]],
    min_gap_minutes: int,
) -> bool:
    slot_end = slot_start + timedelta(minutes=duration_minutes)
    gap = timedelta(minutes=min_gap_minutes)
    for s, e, _ in busy:
        if slot_start < e + gap and slot_end + gap > s:
            return False
    for s, e in proposed:
        if slot_start < e + gap and slot_end + gap > s:
            return False
    return True


def _slot_score(
    activity_type: str, slot_start: datetime, focus_profile: List[float],
) -> float:
    hour = slot_start.hour
    focus = focus_profile[hour]  # 0..100
    if activity_type in ("focus", "quiz"):
        # Cognitive work — reward peak focus strongly
        return focus
    if activity_type == "flashcard":
        # Flashcards benefit from focus but tolerate mid-range too
        return focus * 0.8 + 20
    # light_review — actively prefer moderate focus so peaks stay free
    return 60 + (10 - abs(focus - 55)) * 2


def _run_scheduler(
    user: User, db: Session, cfg: SmartScheduleConfig, days: int,
) -> List[dict]:
    horizon_start = datetime.now(timezone.utc) + timedelta(minutes=30)
    horizon_end   = horizon_start + timedelta(days=days)

    focus_profile = _peak_focus_profile(user, db)
    conflicts     = _collect_conflicts(user, db, cfg, horizon_start, horizon_end)
    need_pool     = _build_need_pool(user, db, cfg)

    # Per-type weekly quotas
    quotas = {
        "focus":        cfg.focus_sessions_per_week      if cfg.enable_focus_sessions else 0,
        "flashcard":    cfg.flashcard_blocks_per_week    if cfg.enable_flashcards     else 0,
        "quiz":         cfg.quiz_blocks_per_week         if cfg.enable_quizzes        else 0,
        "light_review": cfg.light_review_blocks_per_week if cfg.enable_light_review   else 0,
    }
    # Scale quotas linearly for non-7-day horizons (preview might be shorter)
    scale = days / 7.0
    quotas = {k: max(0, round(v * scale)) for k, v in quotas.items()}

    # Candidate queue — flatten pool, tag with need_score, keep per-type FIFO
    per_type_queue: Dict[str, List[dict]] = {k: list(v) for k, v in need_pool.items()}

    all_slots = _iter_slots(horizon_start, horizon_end, cfg)

    proposed: List[dict] = []
    proposed_windows: List[Tuple[datetime, datetime]] = []

    # Score every (slot, activity_type) pair up-front, then pick greedily.
    scored: List[Tuple[float, datetime, str]] = []
    for slot in all_slots:
        for atype in ("focus", "quiz", "flashcard", "light_review"):
            if quotas.get(atype, 0) <= 0:
                continue
            if not per_type_queue.get(atype):
                continue
            scored.append((_slot_score(atype, slot, focus_profile), slot, atype))
    scored.sort(key=lambda x: -x[0])

    placed_counts: Dict[str, int] = defaultdict(int)

    for score, slot, atype in scored:
        if placed_counts[atype] >= quotas.get(atype, 0):
            continue
        if not per_type_queue.get(atype):
            continue
        candidate = per_type_queue[atype][0]
        duration = candidate["duration_minutes"]
        if not _slot_free(slot, duration, conflicts, proposed_windows, cfg.min_gap_minutes):
            continue

        end = slot + timedelta(minutes=duration)
        proposed.append({
            "id": f"preview_{len(proposed)}",
            "activity_type": atype,
            "title": candidate["title"],
            "subject_id": candidate.get("subject_id"),
            "subject_name": candidate.get("subject_name"),
            "subject_color": candidate.get("subject_color"),
            "topic": candidate.get("topic"),
            "start_time": slot.isoformat(),
            "end_time": end.isoformat(),
            "duration_minutes": duration,
            "focus_score_at_slot": round(focus_profile[slot.hour], 1),
            "need_score": candidate.get("need_score"),
            "reason": candidate.get("reason"),
        })
        proposed_windows.append((slot, end))
        placed_counts[atype] += 1
        per_type_queue[atype].pop(0)

    proposed.sort(key=lambda b: b["start_time"])
    return proposed


#  PREVIEW + COMMIT

@router.get("/preview")
def preview(
    days: int = Query(7, ge=1, le=14, description="Planning horizon in days"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cfg = _ensure_config(current_user, db)
    if not cfg.enabled:
        return {
            "enabled": False,
            "blocks": [],
            "message": "Smart scheduler is disabled in your settings.",
        }

    blocks = _run_scheduler(current_user, db, cfg, days)
    cfg.last_plan_generated_at = datetime.now(timezone.utc)
    db.commit()

    # Summary stats for the UI header
    summary = {
        "total_blocks": len(blocks),
        "by_type": {},
        "total_minutes": sum(b["duration_minutes"] for b in blocks),
        "peak_focus_hour": max(range(24),
            key=lambda h: _peak_focus_profile(current_user, db)[h]),
    }
    for b in blocks:
        summary["by_type"].setdefault(b["activity_type"], 0)
        summary["by_type"][b["activity_type"]] += 1

    return {
        "enabled": True,
        "horizon_days": days,
        "generated_at": cfg.last_plan_generated_at.isoformat(),
        "config": _config_to_dict(cfg),
        "summary": summary,
        "blocks": blocks,
    }


@router.post("/commit")
def commit_plan(
    body: CommitPayload,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cfg = _ensure_config(current_user, db)
    created: List[dict] = []
    failures: List[str] = []

    for b in body.blocks:
        # Map activity_type → StudyEvent.event_type
        event_type = {
            "focus": "study",
            "flashcard": "flashcard",
            "quiz": "quiz",
            "light_review": "review",
        }.get(b.activity_type, "study")

        start_utc = _as_utc(b.start_time)
        end_utc = _as_utc(b.end_time)
        duration = max(1, int((end_utc - start_utc).total_seconds() / 60))

        event = StudyEvent(
            user_id=current_user.id,
            title=b.title,
            description=b.reason or f"AI-scheduled {b.activity_type}",
            event_type=event_type,
            subject_name=b.subject_name,
            subject_color=b.subject_color or "#9DD4F0",
            topic=b.topic,
            start_time=start_utc,
            end_time=end_utc,
            duration_minutes=duration,
            source="ai_schedule",
        )
        db.add(event)
        db.flush()  # get event.id

        if body.push_to_gcal:
            try:
                _try_gcal_push(current_user, event, db, update=False)
            except Exception as e:
                failures.append(f"GCal push for '{b.title}': {e}")

        created.append({
            "id": str(event.id),
            "title": event.title,
            "start_time": event.start_time.isoformat(),
            "end_time": event.end_time.isoformat(),
            "event_type": event.event_type,
            "gcal_synced": event.gcal_event_id is not None,
        })

    cfg.last_plan_committed_at = datetime.now(timezone.utc)
    db.commit()

    # Fan out a single "AI scheduled N sessions" notification so the bell
    # in the dashboard lights up right after the user approves a plan.
    # We use a roll-up (not one row per block) to avoid flooding the tray.
    try:
        if current_user.notifications_enabled and created:
            from app.models.notification import Notification as _Notif
            first_start_iso = created[0]["start_time"]
            first_start = datetime.fromisoformat(first_start_iso)
            from app.routers.notifications import _fmt_when as _fmt
            msg = (f"I lined up {len(created)} focused "
                   f"block{'s' if len(created) != 1 else ''} — "
                   f"the first one is {_fmt(first_start)}.")
            db.add(_Notif(
                user_id=current_user.id,
                kind="ai_schedule",
                title=(f"AI scheduled {len(created)} session"
                       f"{'s' if len(created) != 1 else ''}"),
                body=msg,
            ))
            db.commit()
    except Exception as exc:  # noqa: BLE001
        print(f"[SMART_SCHEDULE] Failed to create AI notification: {exc}")

    return {
        "committed": len(created),
        "events": created,
        "warnings": failures,
    }


#  DEBUG: expose peak-focus profile for the UI

@router.get("/focus-profile")
def focus_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    prof = _peak_focus_profile(current_user, db)
    best = max(range(24), key=lambda h: prof[h])
    return {
        "by_hour": [round(v, 1) for v in prof],
        "best_hour": best,
        "best_hour_score": round(prof[best], 1),
    }
