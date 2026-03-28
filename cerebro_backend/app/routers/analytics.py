from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func, desc
from datetime import datetime, timedelta, date, timezone
from decimal import Decimal
from collections import defaultdict
from typing import List, Dict, Any
import traceback

from app.database import get_db
from app.models.user import User
from app.models.study import Subject, StudySession, Quiz, Flashcard
from app.services.ai_coach import generate_coach_briefing
from app.utils.auth import get_current_user

router = APIRouter(prefix="/study", tags=["study-analytics"])


def _safe_mean(values: list) -> float:
    return sum(values) / len(values) if values else 0.0


def _aware(dt):
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _severity(proficiency: float) -> str:
    if proficiency < 40:
        return "critical"
    elif proficiency < 60:
        return "high"
    elif proficiency < 75:
        return "medium"
    return "ok"


def _recommended_action(severity: str, quiz_avg: float, focus_avg: float, card_acc: float) -> str:
    if severity == "critical":
        if quiz_avg < 40:
            return "Start with fundamentals — review notes and do practice problems"
        return "Focused review session + practice problems needed"
    elif severity == "high":
        if card_acc < 0.5:
            return "Create flashcards and review daily"
        return "Practice sessions with spaced repetition"
    elif severity == "medium":
        if focus_avg < 65:
            return "Try focused study sessions with fewer distractions"
        return "Light review to reinforce concepts"
    return "On track — maintain your pace"


@router.get("/analytics")
def get_study_analytics(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return _compute_analytics(current_user, db)
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


def _compute_analytics(current_user: User, db: Session):
    user_id = current_user.id
    now = datetime.now(timezone.utc)
    week_ago = now - timedelta(days=7)
    month_ago = now - timedelta(days=30)

    subjects = db.query(Subject).filter(Subject.user_id == user_id).all()
    sessions = db.query(StudySession).filter(StudySession.user_id == user_id).all()
    quizzes = db.query(Quiz).filter(Quiz.user_id == user_id).all()
    flashcards = db.query(Flashcard).filter(Flashcard.user_id == user_id).all()

    topic_data: Dict[str, Dict[str, Any]] = defaultdict(lambda: {
        "quiz_scores": [], "focus_scores": [], "card_correct": 0, "card_total": 0,
        "subject_name": "", "subject_color": "#9DD4F0", "session_count": 0,
        "last_studied": None,
    })

    # Index sessions by subject_id for quick lookup
    sessions_by_subject: Dict[str, list] = defaultdict(list)
    for s in sessions:
        if s.subject_id:
            sessions_by_subject[str(s.subject_id)].append(s)

    quizzes_by_subject: Dict[str, list] = defaultdict(list)
    for q in quizzes:
        if q.subject_id:
            quizzes_by_subject[str(q.subject_id)].append(q)

    cards_by_subject: Dict[str, list] = defaultdict(list)
    for c in flashcards:
        if c.subject_id:
            cards_by_subject[str(c.subject_id)].append(c)

    #  KNOWLEDGE MAP
    km_subjects = []
    all_topics_set = set()

    for subj in subjects:
        sid = str(subj.id)
        subj_sessions = sessions_by_subject.get(sid, [])
        subj_quizzes = quizzes_by_subject.get(sid, [])
        subj_cards = cards_by_subject.get(sid, [])

        # Collect all topics for this subject
        topics_map: Dict[str, Dict] = defaultdict(lambda: {
            "quiz_scores": [], "focus_scores": [], "card_correct": 0,
            "card_total": 0, "session_count": 0, "last_studied": None,
        })

        for sess in subj_sessions:
            if sess.topics_covered:
                for t in sess.topics_covered:
                    t_lower = t.strip()
                    if not t_lower:
                        continue
                    topics_map[t_lower]["session_count"] += 1
                    if sess.focus_score and sess.focus_score > 0:
                        topics_map[t_lower]["focus_scores"].append(sess.focus_score)
                    if sess.start_time:
                        s_time = _aware(sess.start_time)
                        existing = topics_map[t_lower]["last_studied"]
                        if existing is None or s_time > _aware(existing):
                            topics_map[t_lower]["last_studied"] = s_time

        for quiz in subj_quizzes:
            try:
                pct = float(Decimal(str(quiz.score_achieved)) / Decimal(str(quiz.max_score)) * 100) if quiz.max_score and quiz.score_achieved is not None and float(str(quiz.max_score)) > 0 else 0
            except Exception:
                pct = 0
            if quiz.topics_tested:
                for t in quiz.topics_tested:
                    t_lower = t.strip()
                    if t_lower:
                        topics_map[t_lower]["quiz_scores"].append(pct)
            # Also mark weak topics with penalty
            if quiz.weak_topics:
                for t in quiz.weak_topics:
                    t_lower = t.strip()
                    if t_lower:
                        topics_map[t_lower]["quiz_scores"].append(max(0, pct - 20))

        for card in subj_cards:
            if card.tags:
                for t in card.tags:
                    t_lower = t.strip()
                    if t_lower:
                        topics_map[t_lower]["card_correct"] += (card.correct_reviews or 0)
                        topics_map[t_lower]["card_total"] += (card.total_reviews or 0)

        # Build per-topic proficiency
        subj_topics = []
        for topic_name, td in topics_map.items():
            all_topics_set.add(topic_name)
            quiz_avg = _safe_mean(td["quiz_scores"])
            focus_avg = _safe_mean(td["focus_scores"])
            card_acc = (td["card_correct"] / td["card_total"]) if td["card_total"] > 0 else 0.5

            # Weighted proficiency
            proficiency = (quiz_avg * 0.5) + (focus_avg * 0.3) + (card_acc * 100 * 0.2)
            proficiency = max(0, min(100, proficiency))

            # Also populate global topic_data for gap detection
            key = f"{topic_name}|{subj.name}"
            topic_data[key] = {
                "topic": topic_name, "subject_name": subj.name,
                "subject_color": subj.color or "#9DD4F0",
                "proficiency": round(proficiency, 1),
                "quiz_avg": round(quiz_avg, 1), "focus_avg": round(focus_avg, 1),
                "card_accuracy": round(card_acc, 2),
                "days_since_studied": (
                    (now - _aware(td["last_studied"])).days if td["last_studied"] else 999
                ),
                "session_count": td["session_count"],
            }

            subj_topics.append({
                "name": topic_name,
                "proficiency": round(proficiency, 1),
                "quiz_avg": round(quiz_avg, 1),
                "focus_avg": round(focus_avg, 1),
                "card_accuracy": round(card_acc, 2),
                "session_count": td["session_count"],
            })

        # Sort topics by proficiency ascending (weakest first)
        subj_topics.sort(key=lambda x: x["proficiency"])

        km_subjects.append({
            "id": str(subj.id),
            "name": subj.name,
            "color": subj.color or "#9DD4F0",
            "icon": subj.icon or "book",
            "proficiency": float(str(subj.current_proficiency or 0)),
            "topics": subj_topics,
        })

    #  FALLBACK: Build topics from GeneratedQuiz questions directly
    #  (catches quizzes not linked to subjects or with missing topics)
    if not all_topics_set:
        try:
            from app.models.quiz_engine import GeneratedQuiz, QuizQuestion
            from decimal import Decimal as FBDecimal

            completed_quizzes = (
                db.query(GeneratedQuiz)
                .filter(
                    GeneratedQuiz.user_id == user_id,
                    GeneratedQuiz.status == "completed",
                )
                .all()
            )

            fb_topics_map: Dict[str, Dict] = defaultdict(lambda: {
                "quiz_scores": [], "focus_scores": [], "card_correct": 0,
                "card_total": 0, "session_count": 0, "last_studied": None,
            })

            for gq in completed_quizzes:
                subj_name = "General"
                subj_color = "#9DD4F0"
                if gq.subject_id:
                    for s in subjects:
                        if str(s.id) == str(gq.subject_id):
                            subj_name = s.name
                            subj_color = s.color or "#9DD4F0"
                            break

                for question in gq.questions:
                    if question.topic and question.topic.strip():
                        t = question.topic.strip()
                        all_topics_set.add(t)
                        fb_topics_map[t]["session_count"] += 1
                        if question.is_correct is True:
                            fb_topics_map[t]["quiz_scores"].append(100)
                        elif question.is_correct is False:
                            fb_topics_map[t]["quiz_scores"].append(0)
                        if gq.completed_at:
                            existing = fb_topics_map[t]["last_studied"]
                            ca = _aware(gq.completed_at)
                            if existing is None or ca > _aware(existing):
                                fb_topics_map[t]["last_studied"] = ca

            # Also pull flashcard tags
            for card in flashcards:
                if card.tags:
                    for t in card.tags:
                        t = t.strip()
                        if t:
                            all_topics_set.add(t)
                            fb_topics_map[t]["card_correct"] += (card.correct_reviews or 0)
                            fb_topics_map[t]["card_total"] += (card.total_reviews or 0)

            # Build a pseudo-subject for the knowledge map
            if fb_topics_map:
                fb_subj_topics = []
                for topic_name, td in fb_topics_map.items():
                    quiz_avg = _safe_mean(td["quiz_scores"])
                    focus_avg = _safe_mean(td["focus_scores"])
                    card_acc = (td["card_correct"] / td["card_total"]) if td["card_total"] > 0 else 0.5
                    proficiency = (quiz_avg * 0.5) + (focus_avg * 0.3) + (card_acc * 100 * 0.2)
                    proficiency = max(0, min(100, proficiency))

                    # Add to global topic_data for gap detection
                    key = f"{topic_name}|Quiz Topics"
                    topic_data[key] = {
                        "topic": topic_name, "subject_name": "Quiz Topics",
                        "subject_color": "#CDA8D8",
                        "proficiency": round(proficiency, 1),
                        "quiz_avg": round(quiz_avg, 1), "focus_avg": round(focus_avg, 1),
                        "card_accuracy": round(card_acc, 2),
                        "days_since_studied": (
                            (now - _aware(td["last_studied"])).days if td["last_studied"] else 999
                        ),
                        "session_count": td["session_count"],
                    }

                    fb_subj_topics.append({
                        "name": topic_name,
                        "proficiency": round(proficiency, 1),
                        "quiz_avg": round(quiz_avg, 1),
                        "focus_avg": round(focus_avg, 1),
                        "card_accuracy": round(card_acc, 2),
                        "session_count": td["session_count"],
                    })

                fb_subj_topics.sort(key=lambda x: x["proficiency"])
                km_subjects.append({
                    "id": "quiz-topics",
                    "name": "Quiz Topics",
                    "color": "#CDA8D8",
                    "icon": "quiz",
                    "proficiency": round(_safe_mean([t["proficiency"] for t in fb_subj_topics]), 1),
                    "topics": fb_subj_topics,
                })
                print(f"[ANALYTICS] Fallback found {len(fb_subj_topics)} topics from GeneratedQuiz")

        except Exception as e:
            print(f"[ANALYTICS] Fallback topic scan failed: {e}")
            import traceback; traceback.print_exc()

    #  KNOWLEDGE GAPS
    gaps = []
    for key, td in topic_data.items():
        sev = _severity(td["proficiency"])
        if sev != "ok":
            gaps.append({
                "topic": td["topic"],
                "subject_name": td["subject_name"],
                "subject_color": td["subject_color"],
                "proficiency": td["proficiency"],
                "severity": sev,
                "quiz_avg": td["quiz_avg"],
                "focus_avg": td["focus_avg"],
                "card_accuracy": td["card_accuracy"],
                "days_since_studied": td["days_since_studied"],
                "recommended_action": _recommended_action(
                    sev, td["quiz_avg"], td["focus_avg"], td["card_accuracy"]),
            })

    # Sort by severity (critical first), then by proficiency ascending
    severity_order = {"critical": 0, "high": 1, "medium": 2}
    gaps.sort(key=lambda x: (severity_order.get(x["severity"], 3), x["proficiency"]))

    # Also flag subjects that are far below target
    flagged_subjects = []
    for subj in subjects:
        current = float(str(subj.current_proficiency or 0))
        target = float(str(subj.target_proficiency or 100))
        gap_pct = target - current
        if gap_pct > 30:
            flagged_subjects.append({
                "subject_id": str(subj.id),
                "name": subj.name,
                "color": subj.color or "#9DD4F0",
                "current_proficiency": current,
                "target_proficiency": target,
                "gap_percentage": round(gap_pct, 1),
            })

    #  PREDICTIONS

    # Exam readiness (weighted average of recent performance)
    recent_quiz_scores = []
    for q in sorted(quizzes, key=lambda x: _aware(x.created_at) if x.created_at else now, reverse=True)[:10]:
        try:
            if q.max_score and q.score_achieved is not None and float(str(q.max_score)) > 0:
                recent_quiz_scores.append(
                    float(Decimal(str(q.score_achieved)) / Decimal(str(q.max_score)) * 100)
                )
        except Exception:
            pass
    recent_focus = [
        s.focus_score for s in sessions
        if s.focus_score and s.focus_score > 0 and s.start_time and _aware(s.start_time) >= month_ago
    ]
    card_acc_list = [
        c.correct_reviews / c.total_reviews
        for c in flashcards
        if c.total_reviews and c.total_reviews > 0
    ]

    quiz_mean = _safe_mean(recent_quiz_scores) if recent_quiz_scores else 50
    focus_mean = _safe_mean(recent_focus) if recent_focus else 70
    card_mean = _safe_mean(card_acc_list) if card_acc_list else 0.5

    exam_readiness = round((quiz_mean * 0.6) + (focus_mean * 0.2) + (card_mean * 100 * 0.2), 1)
    exam_readiness = max(0, min(100, exam_readiness))
    confidence = round(min(0.95, 0.5 + len(recent_quiz_scores) / 20), 2)

    # Subject predictions (simple linear projection)
    subject_predictions = []
    for subj in subjects:
        sid = str(subj.id)
        subj_sessions_sorted = sorted(
            [s for s in sessions_by_subject.get(sid, []) if s.start_time],
            key=lambda x: x.start_time
        )
        current_prof = float(str(subj.current_proficiency or 0))

        # Calculate trend from last 4 weeks of sessions
        if len(subj_sessions_sorted) >= 2:
            recent = [s for s in subj_sessions_sorted if _aware(s.start_time) >= month_ago]
            if recent:
                # Simple growth rate based on focus score improvement
                first_half = recent[:len(recent)//2] if len(recent) > 1 else recent
                second_half = recent[len(recent)//2:] if len(recent) > 1 else recent
                early_focus = _safe_mean([s.focus_score for s in first_half if s.focus_score])
                late_focus = _safe_mean([s.focus_score for s in second_half if s.focus_score])
                weekly_growth = (late_focus - early_focus) / max(1, len(recent)) * 2
            else:
                weekly_growth = 0
        else:
            weekly_growth = 0

        predicted_30 = round(max(0, min(100, current_prof + weekly_growth * 4.3)), 1)
        predicted_90 = round(max(0, min(100, current_prof + weekly_growth * 12.9)), 1)

        trend = "improving" if weekly_growth > 0.5 else ("declining" if weekly_growth < -0.5 else "steady")

        subject_predictions.append({
            "name": subj.name,
            "color": subj.color or "#9DD4F0",
            "current": current_prof,
            "predicted_30d": predicted_30,
            "predicted_90d": predicted_90,
            "trend": trend,
        })

    # Weekly study minutes & focus (last 7 days)
    weekly_minutes = [0] * 7
    weekly_focus_scores: List[List[float]] = [[] for _ in range(7)]
    for s in sessions:
        if s.start_time and _aware(s.start_time) >= week_ago:
            day_idx = (s.start_time.weekday())  # 0=Mon, 6=Sun
            weekly_minutes[day_idx] += (s.duration_minutes or 0)
            if s.focus_score and s.focus_score > 0:
                weekly_focus_scores[day_idx].append(s.focus_score)

    weekly_focus = [round(_safe_mean(day_scores)) if day_scores else 0
                    for day_scores in weekly_focus_scores]

    #  SMART SCHEDULE
    recommendations = []
    for g in gaps[:8]:  # Top 8 gaps
        severity_weight = {"critical": 1.5, "high": 1.2, "medium": 1.0}.get(g["severity"], 1.0)
        urgency = round(
            (1 - g["proficiency"] / 100) *
            (1 + min(g["days_since_studied"], 30) / 14) *
            severity_weight,
            2
        )
        # Recommend duration based on severity
        rec_mins = {"critical": 90, "high": 60, "medium": 45}.get(g["severity"], 30)

        recommendations.append({
            "subject_name": g["subject_name"],
            "subject_color": g["subject_color"],
            "topic": g["topic"],
            "priority": g["severity"],
            "urgency": urgency,
            "reason": f"{g['proficiency']}% proficiency, {g['days_since_studied']}d since studied",
            "recommended_mins": rec_mins,
            "session_type": "review" if g["severity"] == "critical" else "practice",
        })

    recommendations.sort(key=lambda x: -x["urgency"])

    # Flashcard due counts
    today = date.today()
    def _card_date(c):
        d = c.next_review_date
        if d is None:
            return None
        if isinstance(d, datetime):
            return d.date()
        return d
    cards_due = sum(1 for c in flashcards if _card_date(c) is not None and _card_date(c) <= today)
    cards_overdue = sum(1 for c in flashcards if _card_date(c) is not None and _card_date(c) < today)

    #  ENRICHMENT — streaks, momentum, hourly heatmap, 30-day trend

    # Per-day study minutes for the last 30 days (oldest → newest).
    today_d = today
    daily_minutes_30 = [0] * 30
    daily_focus_30: List[List[float]] = [[] for _ in range(30)]
    hourly_minutes = [0] * 24  # last 30 days, summed by hour-of-day
    sessions_logged = 0
    for s in sessions:
        if not s.start_time:
            continue
        st = _aware(s.start_time)
        if st < (now - timedelta(days=30)):
            continue
        sessions_logged += 1
        days_ago = (today_d - st.date()).days
        if 0 <= days_ago < 30:
            idx = 29 - days_ago
            daily_minutes_30[idx] += int(s.duration_minutes or 0)
            if s.focus_score and s.focus_score > 0:
                daily_focus_30[idx].append(float(s.focus_score))
            hourly_minutes[st.hour % 24] += int(s.duration_minutes or 0)

    # Daily focus avg (0 if no sessions that day).
    daily_focus_avg_30 = [round(_safe_mean(d), 1) if d else 0 for d in daily_focus_30]

    # Best study hour (mode of hourly_minutes; -1 if no data).
    best_study_hour = -1
    if any(hourly_minutes):
        best_study_hour = int(max(range(24), key=lambda h: hourly_minutes[h]))

    # Study streak — count consecutive days back from today with > 0 minutes.
    streak_days = 0
    for idx in range(29, -1, -1):
        if daily_minutes_30[idx] > 0:
            streak_days += 1
        else:
            break
    # If today itself has zero but yesterday had > 0, the streak ended yesterday.
    # We still report the current run — but if today is 0, surface 0 to avoid
    # implying the user is "on" right now.
    if daily_minutes_30[-1] == 0:
        streak_days = 0

    # Momentum: this-week minutes vs last-week minutes (delta).
    this_week_total = sum(daily_minutes_30[-7:])
    last_week_total = sum(daily_minutes_30[-14:-7])
    momentum_delta = this_week_total - last_week_total

    # Top subjects (by current proficiency, descending).
    top_subjects = sorted(
        [
            {
                "id": str(s.id),
                "name": s.name,
                "color": s.color or "#9DD4F0",
                "proficiency": float(str(s.current_proficiency or 0)),
            }
            for s in subjects
        ],
        key=lambda x: -x["proficiency"],
    )[:5]

    # Forgetting risk — topics with proficiency * recency penalty.
    # High score = high risk of forgetting (high prof but stale, or low prof + stale).
    forgetting_risk = []
    for key, td in topic_data.items():
        days_stale = td["days_since_studied"]
        if days_stale >= 999:
            continue  # never studied — covered by gaps already
        prof = td["proficiency"]
        # Risk peaks for "you used to know this but it's been a while".
        # Simple model: risk = stale_factor * (1 - prof_decay)
        stale_factor = min(1.0, days_stale / 21.0)  # caps at 3 weeks
        prof_decay = max(0.0, prof / 100.0 - 0.1)
        risk = round(stale_factor * (1.0 - prof_decay) * 100, 1)
        if risk >= 35:
            forgetting_risk.append({
                "topic": td["topic"],
                "subject_name": td["subject_name"],
                "subject_color": td["subject_color"],
                "proficiency": prof,
                "days_since_studied": days_stale,
                "risk_score": risk,
            })
    forgetting_risk.sort(key=lambda x: -x["risk_score"])
    forgetting_risk = forgetting_risk[:6]

    # Quick "headline" stats for surfacing on the overview tile.
    overview = {
        "exam_readiness": exam_readiness,
        "confidence": confidence,
        "streak_days": streak_days,
        "sessions_30d": sessions_logged,
        "this_week_minutes": this_week_total,
        "last_week_minutes": last_week_total,
        "momentum_delta": momentum_delta,
        "best_study_hour": best_study_hour,
        "topics_total": len(all_topics_set),
        "topics_weak": sum(1 for g in gaps if g["severity"] in ("critical", "high")),
        "cards_due": cards_due,
        "subjects_total": len(subjects),
    }

    return {
        "knowledge_map": {"subjects": km_subjects},
        "gaps": gaps,
        "flagged_subjects": flagged_subjects,
        "forgetting_risk": forgetting_risk,
        "top_subjects": top_subjects,
        "overview": overview,
        "trends": {
            "daily_minutes_30": daily_minutes_30,
            "daily_focus_30": daily_focus_avg_30,
            "hourly_minutes": hourly_minutes,
            "best_study_hour": best_study_hour,
            "streak_days": streak_days,
            "momentum_delta": momentum_delta,
            "this_week_minutes": this_week_total,
            "last_week_minutes": last_week_total,
        },
        "predictions": {
            "exam_readiness": exam_readiness,
            "confidence": confidence,
            "subject_predictions": subject_predictions,
            "weekly_minutes": weekly_minutes,
            "weekly_focus": weekly_focus,
        },
        "schedule": {
            "recommendations": recommendations,
            "flashcards_due": cards_due,
            "flashcards_overdue": cards_overdue,
        },
    }


def _build_coach_snapshot(payload: Dict[str, Any]) -> Dict[str, Any]:
    # Reduce full analytics to a compact JSON for the LLM prompt
    #
    overview = payload.get("overview") or {}
    trends = payload.get("trends") or {}
    preds = payload.get("predictions") or {}

    return {
        "exam_readiness": overview.get("exam_readiness", 0),
        "confidence": preds.get("confidence", 0),
        "streak_days": trends.get("streak_days", 0),
        "this_week_minutes": trends.get("this_week_minutes", 0),
        "last_week_minutes": trends.get("last_week_minutes", 0),
        "momentum_minutes_delta": trends.get("momentum_delta", 0),
        "best_study_hour": trends.get("best_study_hour", -1),
        "weekly_minutes_by_day": preds.get("weekly_minutes", []),
        "weekly_focus_by_day": preds.get("weekly_focus", []),
        "top_subjects": payload.get("top_subjects", [])[:4],
        "subject_forecasts": [
            {
                "name": s.get("name"),
                "current": s.get("current"),
                "predicted_30d": s.get("predicted_30d"),
                "trend": s.get("trend"),
            }
            for s in (preds.get("subject_predictions") or [])[:6]
        ],
        "gaps": [
            {
                "topic": g.get("topic"),
                "subject_name": g.get("subject_name"),
                "proficiency": g.get("proficiency"),
                "severity": g.get("severity"),
                "days_since_studied": g.get("days_since_studied"),
            }
            for g in (payload.get("gaps") or [])[:6]
        ],
        "forgetting_risk": payload.get("forgetting_risk", [])[:5],
        "top_recommendations": [
            {
                "topic": r.get("topic"),
                "subject_name": r.get("subject_name"),
                "recommended_mins": r.get("recommended_mins"),
                "reason": r.get("reason"),
            }
            for r in (payload.get("schedule", {}).get("recommendations") or [])[:5]
        ],
        "cards_due": overview.get("cards_due", 0),
        "subjects_total": overview.get("subjects_total", 0),
        "topics_total": overview.get("topics_total", 0),
        "topics_weak": overview.get("topics_weak", 0),
    }


@router.get("/analytics/ai-coach")
def get_ai_coach(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        payload = _compute_analytics(current_user, db)
        snapshot = _build_coach_snapshot(payload)
        briefing = generate_coach_briefing(snapshot)
        return {
            "briefing": briefing,
            "snapshot_summary": {
                "exam_readiness": snapshot["exam_readiness"],
                "streak_days": snapshot["streak_days"],
                "this_week_minutes": snapshot["this_week_minutes"],
                "topics_total": snapshot["topics_total"],
                "gaps_count": len(snapshot["gaps"]),
            },
        }
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
