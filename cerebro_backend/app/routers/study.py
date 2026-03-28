from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.orm import Session
from sqlalchemy import func, cast, Date
from typing import List, Optional
from uuid import UUID
from datetime import date, datetime, timezone

from app.database import get_db
from app.models.user import User
from app.models.study import Subject, StudySession, Quiz, Flashcard, FlashcardDeck
from app.schemas.study import (
    SubjectCreate, SubjectResponse, SubjectUpdate,
    StudySessionCreate, StudySessionResponse, StudySessionUpdate,
    SessionStartRequest, SessionEndRequest, ActiveSessionResponse,
    QuizCreate, QuizResponse,
    FlashcardDeckCreate, FlashcardDeckUpdate, FlashcardDeckResponse,
    FlashcardCreate, FlashcardResponse, FlashcardReview, FlashcardUpdate,
)
from app.utils.auth import get_current_user
from app.routers.topics import resolve_topics_from_names

router = APIRouter(prefix="/study", tags=["study"])


#  SUBJECTS

def _subject_to_response(subj: Subject) -> SubjectResponse:
    total = len(subj.topics or [])
    prof = float(str(subj.current_proficiency or 0))
    mastered = int(round((prof / 100.0) * total)) if total else 0
    # Clamp mastered ≤ total defensively.
    mastered = max(0, min(total, mastered))
    return SubjectResponse(
        id=subj.id,
        name=subj.name,
        code=subj.code,
        color=subj.color,
        icon=subj.icon,
        current_proficiency=subj.current_proficiency,
        target_proficiency=subj.target_proficiency,
        created_at=subj.created_at,
        topics_total=total,
        topics_mastered=mastered,
    )


@router.post("/subjects", response_model=SubjectResponse, status_code=status.HTTP_201_CREATED)
def create_subject(
    data: SubjectCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subject = Subject(user_id=current_user.id, **data.model_dump())
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return _subject_to_response(subject)


@router.get("/subjects", response_model=List[SubjectResponse])
def list_subjects(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subs = db.query(Subject).filter(Subject.user_id == current_user.id).all()
    return [_subject_to_response(s) for s in subs]


@router.get("/subjects/{subject_id}", response_model=SubjectResponse)
def get_subject(
    subject_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subject = db.query(Subject).filter(
        Subject.id == subject_id,
        Subject.user_id == current_user.id,
    ).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    return _subject_to_response(subject)


@router.put("/subjects/{subject_id}", response_model=SubjectResponse)
def update_subject(
    subject_id: UUID,
    updates: SubjectUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subject = db.query(Subject).filter(
        Subject.id == subject_id,
        Subject.user_id == current_user.id,
    ).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(subject, field, value)

    db.commit()
    db.refresh(subject)
    return _subject_to_response(subject)


@router.delete("/subjects/{subject_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_subject(
    subject_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    subject = db.query(Subject).filter(
        Subject.id == subject_id,
        Subject.user_id == current_user.id,
    ).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    db.delete(subject)
    db.commit()


#  STUDY SESSIONS

@router.post("/sessions", response_model=StudySessionResponse, status_code=status.HTTP_201_CREATED)
def create_study_session(
    data: StudySessionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Calculate XP earned – proportional so short sessions still get rewarded
    xp_earned = int(data.duration_minutes / 30 * 25)   # e.g. 5 min → 4 XP
    if data.focus_score and data.focus_score >= 80:
        xp_earned = int(xp_earned * 1.25)  # 25% bonus for high focus

    session = StudySession(
        user_id=current_user.id,
        xp_earned=xp_earned,
        **data.model_dump(),
    )
    db.add(session)
    db.flush()  # get session.id before linking topics

    # Topic linking: resolve user-typed names to Topic rows under this subject
    # (silently no-op if subject_id is None — topics are subject-scoped).
    if data.subject_id and data.topics_covered:
        topics = resolve_topics_from_names(
            db, current_user, data.subject_id, data.topics_covered)
        for t in topics:
            if t not in session.topics:
                session.topics.append(t)

    # Update user XP
    current_user.total_xp += xp_earned
    # Level up check (every 500 XP = 1 level)
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(session)
    return session


@router.get("/sessions", response_model=List[StudySessionResponse])
def list_study_sessions(
    subject_id: Optional[UUID] = Query(None),
    topic_id: Optional[UUID] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    limit: int = Query(default=20, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from app.models.topic import session_topics

    query = db.query(StudySession).filter(StudySession.user_id == current_user.id)
    if subject_id:
        query = query.filter(StudySession.subject_id == subject_id)
    if topic_id:
        # Restrict to sessions linked to this Topic via the association table.
        query = query.join(
            session_topics, session_topics.c.session_id == StudySession.id
        ).filter(session_topics.c.topic_id == topic_id)
    if start_date:
        query = query.filter(cast(StudySession.start_time, Date) >= start_date)
    if end_date:
        query = query.filter(cast(StudySession.start_time, Date) <= end_date)
    return query.order_by(StudySession.start_time.desc()).limit(limit).all()


@router.put("/sessions/{session_id}", response_model=StudySessionResponse)
def update_study_session(
    session_id: UUID,
    updates: StudySessionUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.id == session_id,
        StudySession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Study session not found")

    payload = updates.model_dump(exclude_unset=True)
    new_topic_names = payload.pop("topics_covered", None)

    for field, value in payload.items():
        setattr(session, field, value)

    # Re-link topics if caller supplied them. Empty list = detach all.
    if new_topic_names is not None and session.subject_id:
        topics = resolve_topics_from_names(
            db, current_user, session.subject_id, new_topic_names or [])
        session.topics = topics
        session.topics_covered = [t.name for t in topics]  # keep legacy array in sync
    elif new_topic_names is not None:
        session.topics_covered = new_topic_names or []

    db.commit()
    db.refresh(session)
    return session


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_study_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.id == session_id,
        StudySession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Study session not found")

    # Revert XP
    current_user.total_xp = max(0, current_user.total_xp - session.xp_earned)
    current_user.level = (current_user.total_xp // 500) + 1

    db.delete(session)
    db.commit()


#  LIVE SESSION LIFECYCLE (Option B: persistent global session)
#  These five endpoints drive the "Today's Focus" hero + mini-player.
#  Invariant: at most ONE non-completed session per user, enforced by a
#  partial unique index added in migration 009. That lets the client always
#  fetch "the active session" via GET /sessions/active without pagination.
#
#  State machine:
#      [no row]
#          │ POST /sessions/start
#          ▼
#      running ──PUT /sessions/{id}/pause──▶ paused
#      running ◀──PUT /sessions/{id}/resume── paused
#      running ──PUT /sessions/{id}/end──▶ completed (terminal)
#      paused  ──PUT /sessions/{id}/end──▶ completed (terminal)
#
#  "Pausing counts as a distraction" — per explicit product decision:
#  every /pause call increments `distractions`.


def _elapsed_seconds(session: StudySession, now: Optional[datetime] = None) -> int:
    now = now or datetime.now(timezone.utc)
    start = session.start_time
    if start is None:
        return 0
    # If completed and end_time is set, use it; otherwise now.
    end = session.end_time or now
    # Coerce naïve datetimes to UTC so the subtraction doesn't explode.
    if start.tzinfo is None:
        start = start.replace(tzinfo=timezone.utc)
    if end.tzinfo is None:
        end = end.replace(tzinfo=timezone.utc)
    total = int((end - start).total_seconds())
    total -= int(session.total_paused_seconds or 0)
    if session.status == "paused" and session.paused_at is not None:
        paused_at = session.paused_at
        if paused_at.tzinfo is None:
            paused_at = paused_at.replace(tzinfo=timezone.utc)
        total -= int((now - paused_at).total_seconds())
    return max(0, total)


def _build_active_response(session: StudySession) -> ActiveSessionResponse:
    return ActiveSessionResponse.model_validate({
        "id": session.id,
        "subject_id": session.subject_id,
        "title": session.title,
        "session_type": session.session_type,
        "duration_minutes": session.duration_minutes,
        "start_time": session.start_time,
        "end_time": session.end_time,
        "focus_score": session.focus_score,
        "topics_covered": session.topics_covered or [],
        "notes": session.notes,
        "xp_earned": session.xp_earned or 0,
        "created_at": session.created_at,
        "status": session.status or "completed",
        "paused_at": session.paused_at,
        "total_paused_seconds": session.total_paused_seconds or 0,
        "distractions": session.distractions or 0,
        "topics": list(session.topics or []),
        "elapsed_seconds": _elapsed_seconds(session),
    })


@router.post("/sessions/start", response_model=ActiveSessionResponse,
             status_code=status.HTTP_201_CREATED)
def start_live_session(
    data: SessionStartRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    existing = db.query(StudySession).filter(
        StudySession.user_id == current_user.id,
        StudySession.status != "completed",
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail={
                "code": "ACTIVE_SESSION_EXISTS",
                "message": "A live session is already running. End it first.",
                "active_session_id": str(existing.id),
            },
        )

    now = datetime.now(timezone.utc)
    session = StudySession(
        user_id=current_user.id,
        subject_id=data.subject_id,
        title=data.title,
        session_type=data.session_type,
        duration_minutes=data.planned_duration_minutes,
        start_time=now,
        end_time=None,
        topics_covered=data.topics_covered or [],
        xp_earned=0,
        status="running",
        paused_at=None,
        total_paused_seconds=0,
        distractions=0,
    )
    db.add(session)
    db.flush()

    # Resolve topic names → Topic rows (same policy as /sessions POST).
    if data.subject_id and data.topics_covered:
        topics = resolve_topics_from_names(
            db, current_user, data.subject_id, data.topics_covered)
        for t in topics:
            if t not in session.topics:
                session.topics.append(t)

    db.commit()
    db.refresh(session)
    return _build_active_response(session)


@router.get("/sessions/active")
def get_active_session(
    response: Response,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.user_id == current_user.id,
        StudySession.status != "completed",
    ).first()
    if not session:
        response.status_code = status.HTTP_204_NO_CONTENT
        return None
    return _build_active_response(session)


@router.put("/sessions/{session_id}/pause", response_model=ActiveSessionResponse)
def pause_live_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.id == session_id,
        StudySession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.status == "completed":
        raise HTTPException(status_code=409, detail="Session already completed")
    if session.status == "paused":
        return _build_active_response(session)

    session.status = "paused"
    session.paused_at = datetime.now(timezone.utc)
    session.distractions = (session.distractions or 0) + 1
    db.commit()
    db.refresh(session)
    return _build_active_response(session)


@router.put("/sessions/{session_id}/resume", response_model=ActiveSessionResponse)
def resume_live_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.id == session_id,
        StudySession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.status == "completed":
        raise HTTPException(status_code=409, detail="Session already completed")
    if session.status == "running":
        return _build_active_response(session)

    now = datetime.now(timezone.utc)
    if session.paused_at is not None:
        paused_at = session.paused_at
        if paused_at.tzinfo is None:
            paused_at = paused_at.replace(tzinfo=timezone.utc)
        segment = int((now - paused_at).total_seconds())
        session.total_paused_seconds = (session.total_paused_seconds or 0) + max(0, segment)
    session.status = "running"
    session.paused_at = None
    db.commit()
    db.refresh(session)
    return _build_active_response(session)


@router.put("/sessions/{session_id}/distract",
            response_model=ActiveSessionResponse)
def bump_distraction(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.id == session_id,
        StudySession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.status == "completed":
        raise HTTPException(status_code=409, detail="Session already completed")

    session.distractions = (session.distractions or 0) + 1
    db.commit()
    db.refresh(session)
    return _build_active_response(session)


@router.put("/sessions/{session_id}/end", response_model=StudySessionResponse)
def end_live_session(
    session_id: UUID,
    data: SessionEndRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    session = db.query(StudySession).filter(
        StudySession.id == session_id,
        StudySession.user_id == current_user.id,
    ).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if session.status == "completed":
        # Idempotent — already ended. Return current state rather than 409
        # so the client can confidently retry /end after a dropped ack.
        return session

    now = datetime.now(timezone.utc)

    # If the caller ended while paused, fold the final pause segment first.
    if session.status == "paused" and session.paused_at is not None:
        paused_at = session.paused_at
        if paused_at.tzinfo is None:
            paused_at = paused_at.replace(tzinfo=timezone.utc)
        segment = int((now - paused_at).total_seconds())
        session.total_paused_seconds = (session.total_paused_seconds or 0) + max(0, segment)
        session.paused_at = None

    # Compute real focused duration (never < 1 min — storage constraint).
    focused_seconds = _elapsed_seconds(session, now)
    focused_minutes = max(1, round(focused_seconds / 60))

    # Derive focus score if not provided.
    focus_score = data.focus_score
    if focus_score is None:
        focus_score = max(30, 85 - (session.distractions or 0) * 10)

    # XP: same shape as /sessions POST.
    xp_earned = int(focused_minutes / 30 * 25)
    if focus_score >= 80:
        xp_earned = int(xp_earned * 1.25)

    # Apply.
    session.end_time = now
    session.duration_minutes = focused_minutes
    session.focus_score = focus_score
    session.status = "completed"
    session.xp_earned = xp_earned
    if data.notes is not None:
        session.notes = data.notes
    # topics_covered updates reuse the same resolver as /sessions PUT.
    if data.topics_covered is not None:
        if session.subject_id:
            topics = resolve_topics_from_names(
                db, current_user, session.subject_id, data.topics_covered or [])
            session.topics = topics
            session.topics_covered = [t.name for t in topics]
        else:
            session.topics_covered = data.topics_covered or []

    # Award XP on the user row.
    current_user.total_xp = (current_user.total_xp or 0) + xp_earned
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(session)
    return session


#  QUIZZES

@router.post("/quizzes", response_model=QuizResponse, status_code=status.HTTP_201_CREATED)
def create_quiz(
    data: QuizCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = Quiz(user_id=current_user.id, **data.model_dump())
    db.add(quiz)
    db.flush()  # get quiz.id before linking topics

    # Resolve topic names (union of tested + weak) into Topic rows under subject.
    if data.subject_id:
        all_names = list(data.topics_tested or []) + list(data.weak_topics or [])
        if all_names:
            topics = resolve_topics_from_names(
                db, current_user, data.subject_id, all_names)
            for t in topics:
                if t not in quiz.topics:
                    quiz.topics.append(t)

    # Award XP for quiz completion
    percentage = float(data.score_achieved / data.max_score * 100)
    xp_earned = 15 if percentage >= 70 else 5
    current_user.total_xp += xp_earned
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(quiz)
    return quiz


@router.get("/quizzes", response_model=List[QuizResponse])
def list_quizzes(
    subject_id: Optional[UUID] = Query(None),
    topic_id: Optional[UUID] = Query(None),
    limit: int = Query(default=20, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from app.models.topic import quiz_topics

    query = db.query(Quiz).filter(Quiz.user_id == current_user.id)
    if subject_id:
        query = query.filter(Quiz.subject_id == subject_id)
    if topic_id:
        query = query.join(
            quiz_topics, quiz_topics.c.quiz_id == Quiz.id
        ).filter(quiz_topics.c.topic_id == topic_id)
    return query.order_by(Quiz.date_taken.desc()).limit(limit).all()


@router.put("/quizzes/{quiz_id}")
def update_quiz(
    quiz_id: UUID,
    data: QuizCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = db.query(Quiz).filter(Quiz.id == quiz_id, Quiz.user_id == current_user.id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    payload = data.model_dump(exclude_unset=True)
    new_tested = payload.pop("topics_tested", None)
    new_weak = payload.pop("weak_topics", None)
    for field, value in payload.items():
        setattr(quiz, field, value)

    # Re-link topics if either list was supplied. Their union determines
    # the canonical topic association set; the legacy ARRAY columns are
    # kept in sync for backward compatibility.
    if (new_tested is not None or new_weak is not None) and quiz.subject_id:
        tested = new_tested if new_tested is not None else (quiz.topics_tested or [])
        weak = new_weak if new_weak is not None else (quiz.weak_topics or [])
        all_names = list(tested) + list(weak)
        topics = resolve_topics_from_names(
            db, current_user, quiz.subject_id, all_names)
        quiz.topics = topics
        if new_tested is not None:
            quiz.topics_tested = list(new_tested)
        if new_weak is not None:
            quiz.weak_topics = list(new_weak)

    db.commit()
    db.refresh(quiz)
    return quiz


@router.delete("/quizzes/{quiz_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_quiz(
    quiz_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = db.query(Quiz).filter(Quiz.id == quiz_id, Quiz.user_id == current_user.id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    # Revert XP
    percentage = float(quiz.score_achieved / quiz.max_score * 100) if quiz.max_score > 0 else 0
    xp_to_remove = 15 if percentage >= 70 else 5
    current_user.total_xp = max(0, current_user.total_xp - xp_to_remove)
    current_user.level = (current_user.total_xp // 500) + 1
    db.delete(quiz)
    db.commit()


#  FLASHCARD DECKS

def _deck_stats(deck, db):
    from datetime import date as _date

    cards = db.query(Flashcard).filter(Flashcard.deck_id == deck.id).all()
    total = len(cards)
    due = sum(1 for c in cards if c.next_review_date and c.next_review_date <= _date.today())
    mastered = sum(1 for c in cards if c.repetitions >= 3 and float(c.ease_factor) >= 2.5)
    pct = round(100.0 * mastered / total, 1) if total > 0 else 0.0
    return total, due, pct


def _deck_to_dict(deck, db):
    card_count, due_count, mastery_pct = _deck_stats(deck, db)
    return {
        "id": deck.id, "subject_id": deck.subject_id,
        "name": deck.name, "description": deck.description or "",
        "color": deck.color, "icon": deck.icon,
        "card_count": card_count, "due_count": due_count, "mastery_pct": mastery_pct,
        "created_at": deck.created_at, "updated_at": deck.updated_at,
        # Embedded topic chips for the UI — mirrors every other content type.
        "topic_refs": [
            {"id": str(t.id), "name": t.name, "color": t.color}
            for t in (deck.topics or [])
        ],
    }


@router.post("/decks")
def create_deck(
    data: FlashcardDeckCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = FlashcardDeck(user_id=current_user.id, **data.model_dump())
    db.add(deck)
    db.commit()
    db.refresh(deck)
    return _deck_to_dict(deck, db)


@router.get("/decks")
def list_decks(
    subject_id: Optional[UUID] = Query(None),
    topic_id: Optional[UUID] = Query(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from app.models.topic import deck_topics
    # Auto-migrate orphan cards (deck_id == NULL) into an Unsorted deck
    orphan_count = db.query(Flashcard).filter(
        Flashcard.user_id == current_user.id,
        Flashcard.deck_id == None,
    ).count()
    if orphan_count > 0:
        unsorted = db.query(FlashcardDeck).filter(
            FlashcardDeck.user_id == current_user.id,
            FlashcardDeck.name == "Unsorted",
        ).first()
        if not unsorted:
            unsorted = FlashcardDeck(
                user_id=current_user.id,
                name="Unsorted",
                description="Cards created before the deck system",
                color="#C2E8BC",
                icon="inbox",
            )
            db.add(unsorted)
            db.flush()
        db.query(Flashcard).filter(
            Flashcard.user_id == current_user.id,
            Flashcard.deck_id == None,
        ).update({Flashcard.deck_id: unsorted.id}, synchronize_session="fetch")
        db.commit()

    query = db.query(FlashcardDeck).filter(FlashcardDeck.user_id == current_user.id)
    if subject_id:
        query = query.filter(FlashcardDeck.subject_id == subject_id)
    if topic_id:
        query = query.join(
            deck_topics, deck_topics.c.deck_id == FlashcardDeck.id
        ).filter(deck_topics.c.topic_id == topic_id)
    decks = query.order_by(FlashcardDeck.updated_at.desc()).all()
    return [_deck_to_dict(d, db) for d in decks]


@router.get("/decks/{deck_id}")
def get_deck(
    deck_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = db.query(FlashcardDeck).filter(
        FlashcardDeck.id == deck_id,
        FlashcardDeck.user_id == current_user.id,
    ).first()
    if not deck:
        raise HTTPException(status_code=404, detail="Deck not found")
    result = _deck_to_dict(deck, db)
    cards = db.query(Flashcard).filter(Flashcard.deck_id == deck_id).all()
    # IMPORTANT: include `subject_id`, `deck_id`, and `topic_refs` so the
    # frontend's subject/topic filters and per-tile badges work the same
    # whether the UI is fetching `/flashcards` or `/decks/{id}`. Omitting
    # these fields earlier caused "filter by subject returns 0 cards"
    # when a deck was selected — the cards DID have subject_id in the DB,
    # but the payload simply didn't carry it over the wire.
    result["flashcards"] = [
        {"id": str(c.id),
         "subject_id": str(c.subject_id) if c.subject_id else None,
         "deck_id": str(c.deck_id) if c.deck_id else None,
         "front_text": c.front_text, "back_text": c.back_text,
         "tags": c.tags, "difficulty": c.difficulty,
         "ease_factor": float(c.ease_factor),
         "repetitions": c.repetitions, "interval_days": c.interval_days,
         "next_review_date": c.next_review_date.isoformat() if c.next_review_date else None,
         "total_reviews": c.total_reviews, "correct_reviews": c.correct_reviews,
         "streak_days": c.streak_days,
         "created_at": c.created_at.isoformat() if c.created_at else None,
         "topic_refs": [
             {"id": str(t.id), "name": t.name, "color": t.color}
             for t in (c.topics or [])
         ]}
        for c in cards
    ]
    return result


@router.put("/decks/{deck_id}")
def update_deck(
    deck_id: UUID,
    updates: FlashcardDeckUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = db.query(FlashcardDeck).filter(
        FlashcardDeck.id == deck_id,
        FlashcardDeck.user_id == current_user.id,
    ).first()
    if not deck:
        raise HTTPException(status_code=404, detail="Deck not found")
    patch = updates.model_dump(exclude_unset=True)
    # Capture subject change intent so we can cascade it to the deck's
    # cards below. This fixes the "deck has subject X but cards show
    # 'No subject'" class of bugs — when you reassign a deck to a
    # subject, every card in that deck should inherit too (unless the
    # card already had its own subject set, which means a human
    # intentionally overrode it via the card edit dialog).
    new_subject_id = patch.get("subject_id", deck.subject_id) \
        if "subject_id" in patch else None
    for field, value in patch.items():
        setattr(deck, field, value)
    if "subject_id" in patch and new_subject_id is not None:
        db.query(Flashcard).filter(
            Flashcard.deck_id == deck.id,
            Flashcard.user_id == current_user.id,
            Flashcard.subject_id == None,  # noqa: E711
        ).update(
            {Flashcard.subject_id: new_subject_id},
            synchronize_session="fetch",
        )
    db.commit()
    db.refresh(deck)
    return _deck_to_dict(deck, db)


@router.delete("/decks/{deck_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_deck(
    deck_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    deck = db.query(FlashcardDeck).filter(
        FlashcardDeck.id == deck_id,
        FlashcardDeck.user_id == current_user.id,
    ).first()
    if not deck:
        raise HTTPException(status_code=404, detail="Deck not found")
    db.delete(deck)
    db.commit()


@router.get("/decks/{deck_id}/due")
def get_deck_due_cards(
    deck_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import date

    deck = db.query(FlashcardDeck).filter(
        FlashcardDeck.id == deck_id,
        FlashcardDeck.user_id == current_user.id,
    ).first()
    if not deck:
        raise HTTPException(status_code=404, detail="Deck not found")

    cards = db.query(Flashcard).filter(
        Flashcard.deck_id == deck_id,
        Flashcard.next_review_date <= date.today(),
    ).order_by(Flashcard.next_review_date).all()

    return [
        {"id": c.id, "deck_id": c.deck_id, "front_text": c.front_text, "back_text": c.back_text,
         "tags": c.tags, "difficulty": c.difficulty, "ease_factor": float(c.ease_factor),
         "repetitions": c.repetitions, "interval_days": c.interval_days,
         "next_review_date": c.next_review_date.isoformat() if c.next_review_date else None,
         "total_reviews": c.total_reviews, "correct_reviews": c.correct_reviews,
         "streak_days": c.streak_days, "created_at": c.created_at.isoformat() if c.created_at else None}
        for c in cards
    ]


#  FLASHCARDS

@router.post("/flashcards", response_model=FlashcardResponse, status_code=status.HTTP_201_CREATED)
def create_flashcard(
    data: FlashcardCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = Flashcard(user_id=current_user.id, **data.model_dump())
    db.add(card)
    db.flush()  # get card.id before linking topics

    # Resolve tag strings into Topic rows under this card's subject.
    if data.subject_id and data.tags:
        topics = resolve_topics_from_names(
            db, current_user, data.subject_id, data.tags)
        for t in topics:
            if t not in card.topics:
                card.topics.append(t)

    db.commit()
    db.refresh(card)
    return card


@router.get("/flashcards", response_model=List[FlashcardResponse])
def list_flashcards(
    subject_id: Optional[UUID] = Query(None),
    topic_id: Optional[UUID] = Query(None),
    due_only: bool = Query(default=False),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import date
    from app.models.topic import flashcard_topics

    query = db.query(Flashcard).filter(Flashcard.user_id == current_user.id)
    if subject_id:
        query = query.filter(Flashcard.subject_id == subject_id)
    if topic_id:
        query = query.join(
            flashcard_topics, flashcard_topics.c.flashcard_id == Flashcard.id
        ).filter(flashcard_topics.c.topic_id == topic_id)
    if due_only:
        query = query.filter(Flashcard.next_review_date <= date.today())
    return query.all()


@router.post("/flashcards/{card_id}/review", response_model=FlashcardResponse)
def review_flashcard(
    card_id: UUID,
    review: FlashcardReview,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import date
    from decimal import Decimal

    card = db.query(Flashcard).filter(
        Flashcard.id == card_id,
        Flashcard.user_id == current_user.id,
    ).first()
    if not card:
        raise HTTPException(status_code=404, detail="Flashcard not found")

    q = review.quality

    # SM-2 Algorithm
    if q >= 3:  # Correct response
        if card.repetitions == 0:
            card.interval_days = 1
        elif card.repetitions == 1:
            card.interval_days = 6
        else:
            card.interval_days = int(card.interval_days * float(card.ease_factor))

        card.repetitions += 1
        card.correct_reviews += 1
    else:  # Incorrect response
        card.repetitions = 0
        card.interval_days = 1

    # Update ease factor
    new_ef = float(card.ease_factor) + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    card.ease_factor = Decimal(str(max(1.3, new_ef)))

    # Update review dates and stats
    card.last_review_date = date.today()
    card.next_review_date = date.today() + __import__("datetime").timedelta(days=card.interval_days)
    card.total_reviews += 1

    # XP for flashcard review
    current_user.total_xp += 5
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(card)
    return card


@router.put("/flashcards/{card_id}", response_model=FlashcardResponse)
def update_flashcard(
    card_id: UUID,
    data: FlashcardUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = db.query(Flashcard).filter(
        Flashcard.id == card_id,
        Flashcard.user_id == current_user.id,
    ).first()
    if not card:
        raise HTTPException(status_code=404, detail="Flashcard not found")

    patch = data.model_dump(exclude_unset=True)

    # Apply scalar fields directly. `tags` is handled after the subject
    # assignment so topic re-resolution uses the final subject_id.
    tags_patch = patch.pop("tags", None)
    for key, value in patch.items():
        setattr(card, key, value)

    # Re-resolve topics if tags were touched. If the card has no
    # subject_id at this point, clear the topics link table since
    # Topics are scoped per-subject.
    if tags_patch is not None:
        card.tags = tags_patch
        card.topics.clear()
        if card.subject_id and tags_patch:
            topics = resolve_topics_from_names(
                db, current_user, card.subject_id, tags_patch)
            for t in topics:
                if t not in card.topics:
                    card.topics.append(t)

    db.commit()
    db.refresh(card)
    return card


@router.delete("/flashcards/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_flashcard(
    card_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = db.query(Flashcard).filter(
        Flashcard.id == card_id,
        Flashcard.user_id == current_user.id,
    ).first()
    if not card:
        raise HTTPException(status_code=404, detail="Flashcard not found")
    db.delete(card)
    db.commit()


@router.post("/flashcards/generate")
def generate_flashcards_from_material(
    data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    import os, json, re
    import httpx

    material_ids = data.get("material_ids", [])
    count = min(data.get("count", 10), 30)
    subject_id = data.get("subject_id")
    deck_id_raw = data.get("deck_id")
    topic_filter_raw = data.get("topic_filter") or []
    topic_filter = [t for t in topic_filter_raw if isinstance(t, str) and t.strip()]

    # Coerce deck_id to a real UUID. The endpoint declares `data: dict`
    # (not a Pydantic model) so incoming JSON string UUIDs arrive as
    # plain str, and SQLAlchemy's UUID(as_uuid=True) column silently
    # fails to persist them correctly — cards were being saved with
    # deck_id=NULL which is why "filter by deck" showed nothing even
    # though the generate snackbar said "added to <deck name>".
    deck_id: Optional[UUID] = None
    if deck_id_raw:
        try:
            deck_id = UUID(str(deck_id_raw))
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail="Invalid deck_id")

    if not material_ids:
        raise HTTPException(status_code=400, detail="material_ids required")

    # If the caller picked a deck, verify it belongs to this user AND
    # use the deck's subject as the default subject for the generated
    # cards. This matters when the user says "generate into the Data &
    # Web deck" — they expect the cards to live under that deck's
    # subject, not under whatever subject the source material happened
    # to have. Explicit `subject_id` in the request still wins.
    deck_subject_id: Optional[UUID] = None
    if deck_id is not None:
        deck = db.query(FlashcardDeck).filter(
            FlashcardDeck.id == deck_id,
            FlashcardDeck.user_id == current_user.id,
        ).first()
        if not deck:
            raise HTTPException(status_code=404, detail="Deck not found")
        deck_subject_id = deck.subject_id

    from app.models.quiz_engine import StudyMaterial
    materials = db.query(StudyMaterial).filter(
        StudyMaterial.id.in_(material_ids),
        StudyMaterial.user_id == current_user.id,
    ).all()
    if not materials:
        raise HTTPException(status_code=404, detail="No materials found")

    combined = "\n\n".join([f"=== {m.title} ===\n{m.content}" for m in materials])
    if len(combined) > 15000:
        combined = combined[:10000] + "\n\n[...]\n\n" + combined[-5000:]

    topic_focus_block = ""
    if topic_filter:
        bullet = "\n".join(f"  - {t}" for t in topic_filter[:20])
        topic_focus_block = (
            f"\n\nFOCUS TOPICS (draw cards only from these — "
            f"ignore unrelated content from the material):\n{bullet}\n"
        )

    prompt = f"""You are an expert teacher creating flashcards from study material.
Create exactly {count} flashcards that help students memorize and understand KEY concepts.

RULES:
1. Each card tests ONE specific concept, fact, or term
2. Front = clear question or prompt. Back = concise answer (1-3 sentences max)
3. For math/science: test definitions, formulas, rules, common mistakes
4. For history/literature: test key events, people, themes, cause-effect
5. Mix difficulty levels — some easy recall, some deeper understanding
6. NEVER make trivial cards. Cards should be useful for actual studying
7. Cover DIFFERENT topics from the material{topic_focus_block}

STUDY MATERIAL:
{combined}

Return ONLY a valid JSON array:
[{{"front":"question","back":"answer","tags":["topic"],"difficulty":3}}]"""

    # Try AI providers
    result_text = None
    for provider, call_fn in [
        ("Groq", lambda: _call_groq_fc(os.environ.get("GROQ_API_KEY"), prompt)),
        ("Anthropic", lambda: _call_anthropic_fc(os.environ.get("ANTHROPIC_API_KEY"), prompt)),
        ("OpenAI", lambda: _call_openai_fc(os.environ.get("OPENAI_API_KEY"), prompt)),
    ]:
        try:
            result_text = call_fn()
            if result_text:
                print(f"[FLASHCARD-GEN] {provider} succeeded")
                break
        except Exception as e:
            print(f"[FLASHCARD-GEN] {provider} failed: {e}")

    if not result_text:
        raise HTTPException(status_code=422,
            detail="No AI API key configured. Set GROQ_API_KEY (free at console.groq.com).")

    # Parse JSON
    text = result_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        cards_data = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", text)
        if match:
            cards_data = json.loads(match.group())
        else:
            raise HTTPException(status_code=500, detail="AI returned invalid format")

    # Create flashcards in DB.
    # Subject resolution priority:
    #   1. explicit subject_id in request body (user override)
    #   2. the chosen deck's subject_id (deck-first grouping)
    #   3. the first source material's subject_id (legacy fallback)
    # This ordering makes "generate into the Data & Web deck" land
    # cards under that deck's subject instead of accidentally tagging
    # them with whatever subject the source material came from.
    _raw_sub = subject_id or deck_subject_id or (materials[0].subject_id if materials else None)
    effective_subject_id = UUID(str(_raw_sub)) if _raw_sub else None

    # Diagnostic log — tail your uvicorn terminal while hitting the
    # Generate button. If this line doesn't appear, the running server
    # is stale and needs to be restarted. If `effective_subject_id=None`
    # when you expected it set, the deck you targeted has a NULL
    # subject_id in the DB (fix with PUT /study/decks/{id} or rerun
    # scripts/peek_deck.py to confirm).
    print(
        f"[FLASHCARD-GEN] deck_id={deck_id} "
        f"deck_subject_id={deck_subject_id} "
        f"req_subject_id={subject_id} "
        f"mat_subject_id={materials[0].subject_id if materials else None} "
        f"-> effective_subject_id={effective_subject_id}"
    )

    created = []
    for cd in cards_data[:count]:
        card = Flashcard(
            user_id=current_user.id,
            subject_id=effective_subject_id,
            deck_id=deck_id,
            front_text=cd.get("front", ""),
            back_text=cd.get("back", ""),
            tags=cd.get("tags", []),
            difficulty=min(5, max(1, cd.get("difficulty", 3))),
        )
        db.add(card)
        created.append((card, cd.get("tags") or []))

    db.flush()  # give all cards UUIDs before topic linking

    # Topic-link each generated card under the effective subject.
    if effective_subject_id:
        for card, tag_list in created:
            if not tag_list:
                continue
            topics = resolve_topics_from_names(
                db, current_user, effective_subject_id, tag_list)
            for t in topics:
                if t not in card.topics:
                    card.topics.append(t)

    db.commit()
    created = [pair[0] for pair in created]
    for c in created:
        db.refresh(c)

    return {"generated": len(created), "cards": [
        {"id": str(c.id),
         "deck_id": str(c.deck_id) if c.deck_id else None,
         "subject_id": str(c.subject_id) if c.subject_id else None,
         "front_text": c.front_text, "back_text": c.back_text,
         "tags": c.tags, "difficulty": c.difficulty,
         "next_review_date": c.next_review_date.isoformat() if c.next_review_date else None}
        for c in created
    ]}


def _call_groq_fc(key, prompt):
    if not key: return None
    import httpx
    r = httpx.post("https://api.groq.com/openai/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={"model": "llama-3.3-70b-versatile", "messages": [{"role": "user", "content": prompt}],
              "max_tokens": 4096, "temperature": 0.3}, timeout=60.0)
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]

def _call_anthropic_fc(key, prompt):
    if not key: return None
    import httpx
    r = httpx.post("https://api.anthropic.com/v1/messages",
        headers={"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"},
        json={"model": "claude-sonnet-4-20250514", "max_tokens": 4096,
              "messages": [{"role": "user", "content": prompt}]}, timeout=60.0)
    r.raise_for_status()
    return r.json()["content"][0]["text"]

def _call_openai_fc(key, prompt):
    if not key: return None
    import httpx
    r = httpx.post("https://api.openai.com/v1/chat/completions",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json={"model": "gpt-4o-mini", "messages": [{"role": "user", "content": prompt}],
              "max_tokens": 4096, "temperature": 0.3}, timeout=60.0)
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]


from app.models.study import ResourceRecommendation


@router.get("/recommendations")
def get_resource_recommendations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    force_refresh: bool = Query(default=False),
):
    from datetime import datetime, timezone
    import json

    if not force_refresh:
        cached = (
            db.query(ResourceRecommendation)
            .filter(
                ResourceRecommendation.user_id == current_user.id,
                ResourceRecommendation.expires_at > datetime.now(timezone.utc),
            )
            .order_by(ResourceRecommendation.generated_at.desc())
            .first()
        )
        if cached:
            data = json.loads(cached.recommendations_data)
            return {
                "id": str(cached.id),
                "cache_hit": True,
                "generated_at": cached.generated_at.isoformat(),
                "expires_at": cached.expires_at.isoformat(),
                **data,
            }

    return _generate_recommendations(current_user, db)


@router.post("/recommendations/refresh")
def refresh_recommendations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Clear old cached recs first
    db.query(ResourceRecommendation).filter(
        ResourceRecommendation.user_id == current_user.id,
    ).delete()
    db.commit()
    return _generate_recommendations(current_user, db)


def _generate_recommendations(current_user: User, db: Session):
    from datetime import datetime, timedelta, timezone
    from decimal import Decimal
    from collections import defaultdict
    import json, os, re, traceback

    gaps = []
    try:
        from app.routers.analytics import _compute_analytics
        analytics = _compute_analytics(current_user, db)
        gaps = analytics.get("gaps", [])[:5]
        print(f"[RECOMMENDATIONS] Analytics returned {len(gaps)} gaps")
    except Exception as e:
        print(f"[RECOMMENDATIONS] Analytics failed: {e}")
        traceback.print_exc()

    if not gaps:
        print("[RECOMMENDATIONS] Trying direct fallback...")
        try:
            from app.models.study import Quiz as LegacyQuiz, Flashcard, Subject
            from app.models.quiz_engine import GeneratedQuiz, QuizQuestion

            topic_stats = defaultdict(lambda: {
                "scores": [], "wrong_count": 0, "total_count": 0,
                "subject_name": "General", "card_correct": 0, "card_total": 0,
            })

            # 1) From legacy Quiz records (created when AI quizzes are completed)
            legacy_quizzes = (
                db.query(LegacyQuiz)
                .filter(LegacyQuiz.user_id == current_user.id)
                .all()
            )
            for q in legacy_quizzes:
                pct = 0
                if q.max_score and float(str(q.max_score)) > 0 and q.score_achieved is not None:
                    pct = float(str(q.score_achieved)) / float(str(q.max_score)) * 100
                subj_name = "General"
                if q.subject_id:
                    subj = db.query(Subject).filter(Subject.id == q.subject_id).first()
                    if subj:
                        subj_name = subj.name
                if q.topics_tested:
                    for t in q.topics_tested:
                        t = t.strip()
                        if t:
                            topic_stats[t]["scores"].append(pct)
                            topic_stats[t]["total_count"] += 1
                            topic_stats[t]["subject_name"] = subj_name
                if q.weak_topics:
                    for t in q.weak_topics:
                        t = t.strip()
                        if t:
                            topic_stats[t]["wrong_count"] += 1
                            topic_stats[t]["subject_name"] = subj_name

            # 2) From GeneratedQuiz questions directly (in case legacy records are missing)
            if not topic_stats:
                completed_quizzes = (
                    db.query(GeneratedQuiz)
                    .filter(
                        GeneratedQuiz.user_id == current_user.id,
                        GeneratedQuiz.status == "completed",
                    )
                    .all()
                )
                for gq in completed_quizzes:
                    subj_name = "General"
                    if gq.subject_id:
                        subj = db.query(Subject).filter(Subject.id == gq.subject_id).first()
                        if subj:
                            subj_name = subj.name
                    for question in gq.questions:
                        if question.topic:
                            t = question.topic.strip()
                            if t:
                                topic_stats[t]["total_count"] += 1
                                topic_stats[t]["subject_name"] = subj_name
                                if question.is_correct is True:
                                    topic_stats[t]["scores"].append(100)
                                elif question.is_correct is False:
                                    topic_stats[t]["scores"].append(0)
                                    topic_stats[t]["wrong_count"] += 1

            # 3) From flashcard review data
            flashcards = (
                db.query(Flashcard)
                .filter(Flashcard.user_id == current_user.id)
                .all()
            )
            for c in flashcards:
                if c.tags:
                    for t in c.tags:
                        t = t.strip()
                        if t:
                            topic_stats[t]["card_correct"] += (c.correct_reviews or 0)
                            topic_stats[t]["card_total"] += (c.total_reviews or 0)

            # Build gap list from collected topic stats
            for topic_name, td in topic_stats.items():
                quiz_avg = sum(td["scores"]) / len(td["scores"]) if td["scores"] else 50
                card_acc = (td["card_correct"] / td["card_total"]) if td["card_total"] > 0 else 0.5
                proficiency = (quiz_avg * 0.7) + (card_acc * 100 * 0.3)
                proficiency = max(0, min(100, proficiency))

                if proficiency < 80:  # Slightly relaxed threshold for fallback
                    severity = "critical" if proficiency < 40 else ("high" if proficiency < 60 else "medium")
                    gaps.append({
                        "topic": topic_name,
                        "subject_name": td["subject_name"],
                        "proficiency": round(proficiency, 1),
                        "severity": severity,
                        "quiz_avg": round(quiz_avg, 1),
                        "card_accuracy": round(card_acc, 2),
                        "days_since_studied": "?",
                    })

            # Sort by severity
            sev_order = {"critical": 0, "high": 1, "medium": 2}
            gaps.sort(key=lambda g: (sev_order.get(g["severity"], 3), g["proficiency"]))
            gaps = gaps[:5]
            print(f"[RECOMMENDATIONS] Fallback found {len(gaps)} gaps")

        except Exception as e:
            print(f"[RECOMMENDATIONS] Fallback also failed: {e}")
            traceback.print_exc()

    if not gaps:
        try:
            from app.models.study import Subject
            subjects = db.query(Subject).filter(Subject.user_id == current_user.id).all()
            for subj in subjects[:3]:
                gaps.append({
                    "topic": subj.name,
                    "subject_name": subj.name,
                    "proficiency": float(str(subj.current_proficiency or 50)),
                    "severity": "medium",
                    "quiz_avg": 50,
                    "card_accuracy": 0.5,
                    "days_since_studied": "?",
                })
            print(f"[RECOMMENDATIONS] Using {len(gaps)} subjects as fallback")
        except Exception as e:
            print(f"[RECOMMENDATIONS] Subject fallback failed: {e}")

    if not gaps:
        empty_result = {
            "weak_areas": [],
            "recommendations": [],
            "videos": [],
            "articles": [],
            "practice_problems": [],
            "techniques": [],
            "message": "You're doing great! Take some quizzes or review flashcards to get personalised recommendations.",
        }
        return {"cache_hit": False, "generated_at": datetime.now(timezone.utc).isoformat(), **empty_result}

    weak_areas_text = "\n".join([
        f"- {g['topic']} ({g['subject_name']}): {g['proficiency']:.0f}% proficiency, "
        f"severity={g['severity']}, quiz_avg={g.get('quiz_avg', 0):.0f}%, "
        f"card_accuracy={g.get('card_accuracy', 0):.0%}, "
        f"days since studied: {g.get('days_since_studied', '?')}"
        for g in gaps
    ])

    prompt = f"""You are an expert educational advisor helping a university student improve their weak areas.

STUDENT PROFILE:
- University: {current_user.university or 'Not specified'}
- Course: {current_user.course or 'General Studies'}
- Year of study: {current_user.year_of_study or 'Unknown'}
- Level: {current_user.level}

TOP WEAK AREAS (ranked by urgency):
{weak_areas_text}

TASK: For each weak area, recommend 2-4 learning strategies across these categories:

1. VIDEO — Describe what KIND of video tutorial to search for (e.g. "Search for an introductory lecture on thermodynamics covering the first law"). Name well-known platforms: Khan Academy, MIT OpenCourseWare, Crash Course, Professor Leonard, 3Blue1Brown, etc. Use the "search_query" field with a good YouTube search query.
2. ARTICLE — Describe what kind of reading material would help. Reference well-known free textbooks (OpenStax), Wikipedia articles, or study guide topics. Use "search_query" for a Google search query.
3. PRACTICE — Describe specific practice exercises, problem types, or interactive tools. Mention platforms like Brilliant.org, Paul's Online Math Notes, or textbook chapter exercises.
4. TECHNIQUE — Describe a concrete study technique tailored to this topic (e.g. Feynman technique for conceptual gaps, spaced repetition for memorisation, worked examples for problem-solving).

CRITICAL RULES:
- Do NOT include any URLs. URLs will be auto-generated from search_query.
- Include a "search_query" field: a short search string (3-8 words) to find this resource on YouTube (for videos) or Google (for articles/practice).
- "why_recommended" must reference the student's specific weakness and explain how this helps.
- Estimated time in minutes.
- Difficulty: beginner / intermediate / advanced.

Return ONLY a valid JSON object:
{{
  "recommendations": [
    {{
      "topic": "the weak area topic name",
      "resource_type": "video",
      "title": "Clear descriptive title",
      "search_query": "thermodynamics first law explained",
      "description": "What you will learn from this",
      "why_recommended": "Your thermodynamics score is 35%. This covers the fundamentals you're missing...",
      "difficulty": "beginner",
      "estimated_minutes": 20,
      "source": "Khan Academy / YouTube"
    }}
  ]
}}"""

    result_text = None
    for provider, call_fn in [
        ("Groq", lambda: _call_groq_fc(os.environ.get("GROQ_API_KEY"), prompt)),
        ("Anthropic", lambda: _call_anthropic_fc(os.environ.get("ANTHROPIC_API_KEY"), prompt)),
        ("OpenAI", lambda: _call_openai_fc(os.environ.get("OPENAI_API_KEY"), prompt)),
    ]:
        try:
            result_text = call_fn()
            if result_text:
                print(f"[RECOMMENDATIONS-AI] {provider} succeeded")
                break
        except Exception as e:
            print(f"[RECOMMENDATIONS-AI] {provider} failed: {e}")

    if not result_text:
        raise HTTPException(
            status_code=422,
            detail="No AI API key configured. Set GROQ_API_KEY in .env (free at console.groq.com).",
        )

    text = result_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\{[\s\S]*\}", text)
        if match:
            data = json.loads(match.group())
        else:
            raise HTTPException(status_code=500, detail="AI returned invalid format")

    recs = data.get("recommendations", [])

    import httpx
    from urllib.parse import quote_plus
    from concurrent.futures import ThreadPoolExecutor, as_completed

    _VIDEO_HINTS = {"youtube", "video", "crash course", "khan academy", "mit ocw",
                    "coursera", "3blue1brown", "professor leonard", "lecture", "tutorial"}
    _ARTICLE_HINTS = {"wikipedia", "article", "openstax", "textbook", "read", "guide",
                      "blog", "documentation", "chapter"}
    _PRACTICE_HINTS = {"practice", "exercise", "problem", "worksheet", "brilliant",
                       "interactive", "drill", "quiz"}
    _TECHNIQUE_HINTS = {"technique", "method", "strategy", "feynman", "spaced repetition",
                        "pomodoro", "mind map", "active recall", "study tip"}

    def _infer_type(rec):
        blob = " ".join([
            rec.get("source", ""), rec.get("title", ""), rec.get("description", "")
        ]).lower()
        if any(h in blob for h in _VIDEO_HINTS):
            return "video"
        if any(h in blob for h in _PRACTICE_HINTS):
            return "practice"
        if any(h in blob for h in _TECHNIQUE_HINTS):
            return "technique"
        if any(h in blob for h in _ARTICLE_HINTS):
            return "article"
        return "article"

    type_map = {
        "video": "video", "videos": "video", "youtube": "video",
        "article": "article", "articles": "article", "textbook": "article",
        "reading": "article", "text": "article",
        "practice": "practice", "exercise": "practice", "exercises": "practice",
        "practice_problems": "practice", "problems": "practice",
        "technique": "technique", "techniques": "technique",
        "study_technique": "technique", "tip": "technique", "strategy": "technique",
    }

    for rec in recs:
        rec.pop("url", None)
        raw_type = (rec.get("resource_type") or "").strip().lower()
        rtype = type_map.get(raw_type) or _infer_type(rec)
        rec["resource_type"] = rtype


    def _find_youtube_video(query: str) -> dict:
        try:
            r = httpx.get(
                "https://www.youtube.com/results",
                params={"search_query": query},
                headers={"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
                timeout=10.0,
                follow_redirects=True,
            )
            # YouTube embeds JSON with videoId in the page HTML
            matches = re.findall(r'"videoId":"([a-zA-Z0-9_-]{11})"', r.text)
            if matches:
                vid = matches[0]
                # Try to extract the video title too
                title_match = re.search(
                    r'"videoId":"' + vid + r'".*?"text":"([^"]{5,100})"', r.text[:5000]
                )
                return {
                    "url": f"https://www.youtube.com/watch?v={vid}",
                    "url_label": "Watch on YouTube",
                    "resolved_title": title_match.group(1) if title_match else None,
                }
        except Exception as e:
            print(f"[YT-SEARCH] Failed for '{query}': {e}")
        return {"url": f"https://www.youtube.com/results?search_query={quote_plus(query)}", "url_label": "Search YouTube"}

    def _find_wikipedia_article(query: str) -> dict:
        try:
            r = httpx.get(
                "https://en.wikipedia.org/w/api.php",
                params={"action": "opensearch", "search": query, "limit": 1, "format": "json"},
                timeout=10.0,
            )
            data_w = r.json()
            if len(data_w) >= 4 and data_w[3] and len(data_w[3]) > 0:
                return {
                    "url": data_w[3][0],
                    "url_label": "Read on Wikipedia",
                    "resolved_title": data_w[1][0] if data_w[1] else None,
                }
        except Exception as e:
            print(f"[WIKI-SEARCH] Failed for '{query}': {e}")
        return {"url": f"https://www.google.com/search?q={quote_plus(query)}", "url_label": "Search Google"}

    def _find_practice_resource(query: str) -> dict:
        try:
            r = httpx.get(
                "https://www.khanacademy.org/api/internal/search",
                params={"search_query": query, "page_size": 1},
                headers={"User-Agent": "Mozilla/5.0"},
                timeout=8.0,
            )
            if r.status_code == 200:
                results = r.json()
                items = results.get("results", results.get("items", []))
                if items and isinstance(items, list) and len(items) > 0:
                    item = items[0]
                    slug = item.get("url") or item.get("ka_url") or item.get("relative_url", "")
                    if slug:
                        url = slug if slug.startswith("http") else f"https://www.khanacademy.org{slug}"
                        return {
                            "url": url,
                            "url_label": "Practice on Khan Academy",
                            "resolved_title": item.get("title"),
                        }
        except Exception as e:
            print(f"[KHAN-SEARCH] Failed for '{query}': {e}")
        # Fallback: Google search for practice problems
        return {
            "url": f"https://www.google.com/search?q={quote_plus(query + ' practice problems free')}",
            "url_label": "Find Practice",
        }

    # Run all URL lookups in parallel for speed
    def _resolve_url(i, rec):
        query = rec.get("search_query") or rec.get("title") or rec.get("topic") or "study resources"
        topic = rec.get("topic", "")
        rtype = rec["resource_type"]

        if rtype == "video":
            return i, _find_youtube_video(f"{query} {topic}".strip())
        elif rtype == "article":
            return i, _find_wikipedia_article(f"{query} {topic}".strip())
        elif rtype == "practice":
            return i, _find_practice_resource(f"{query} {topic}".strip())
        elif rtype == "technique":
            return i, {
                "url": f"https://www.google.com/search?q={quote_plus(query + ' study technique')}",
                "url_label": "Learn More",
            }
        return i, {}

    print(f"[RECOMMENDATIONS] Resolving real URLs for {len(recs)} resources...")
    with ThreadPoolExecutor(max_workers=6) as executor:
        futures = [executor.submit(_resolve_url, i, rec) for i, rec in enumerate(recs)]
        for future in as_completed(futures):
            try:
                idx, result = future.result(timeout=15)
                if result:
                    recs[idx]["url"] = result.get("url")
                    recs[idx]["url_label"] = result.get("url_label", "Open")
            except Exception as e:
                print(f"[RECOMMENDATIONS] URL resolve failed: {e}")
    print("[RECOMMENDATIONS] URL resolution complete")

    categorised = {
        "weak_areas": [
            {"topic": g["topic"], "subject": g["subject_name"],
             "proficiency": round(g["proficiency"], 1), "severity": g["severity"]}
            for g in gaps
        ],
        "recommendations": recs,
        "videos": [r for r in recs if r.get("resource_type") == "video"],
        "articles": [r for r in recs if r.get("resource_type") in ("article", "textbook")],
        "practice_problems": [r for r in recs if r.get("resource_type") == "practice"],
        "techniques": [r for r in recs if r.get("resource_type") == "technique"],
    }

    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=6)

    cache_entry = ResourceRecommendation(
        user_id=current_user.id,
        recommendations_data=json.dumps(categorised),
        generated_at=now,
        expires_at=expires_at,
        analysis_snapshot=json.dumps([
            {"topic": g["topic"], "proficiency": g["proficiency"], "subject": g["subject_name"]}
            for g in gaps
        ]),
    )
    db.add(cache_entry)
    db.commit()

    return {
        "id": str(cache_entry.id),
        "cache_hit": False,
        "generated_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
        **categorised,
    }


from pydantic import BaseModel as PydanticBase
from typing import List as TList


class InstitutionSearchRequest(PydanticBase):
    query: str
    institution_type: str = "university"


class InstitutionResult(PydanticBase):
    name: str
    affiliation: Optional[str] = None
    country: str = ""


@router.post("/search-institutions", response_model=TList[InstitutionResult])
def search_institutions(
    body: InstitutionSearchRequest,
    current_user: User = Depends(get_current_user),
):
    import os, json, re

    query = body.query.strip()
    if len(query) < 3:
        return []

    prompt = f"""You are an education expert with comprehensive knowledge of educational institutions worldwide.

The user is searching for a {body.institution_type.replace('_', ' ')} with query: "{query}"

Return the top 5 most relevant institutions matching this search. For EACH institution, determine:
1. The full official name
2. If it's a college affiliated with or accredited by a university, specify the parent/affiliated university (e.g., "Islington College" is affiliated with "London Metropolitan University", "Softwarica College" is affiliated with "Coventry University")
3. The country

IMPORTANT: For colleges that deliver university-level programmes under franchise/partnership agreements, ALWAYS identify the awarding university. This is critical because students at these colleges study the university's curriculum and need the university's module codes.

Common examples:
- Islington College (Nepal) → Affiliated with London Metropolitan University
- Softwarica College → Affiliated with Coventry University
- Herald College Kathmandu → Affiliated with University of Wolverhampton
- Informatics College → Affiliated with University of Northampton
- LSBU in various countries → London South Bank University partnerships

Return ONLY a JSON array. Each item: {{"name": "string", "affiliation": "Affiliated with X University" or "", "country": "string"}}
If no good matches, return an empty array []."""

    result_text = None
    for provider, call_fn in [
        ("Groq", lambda: _call_groq_fc(os.environ.get("GROQ_API_KEY"), prompt)),
        ("Anthropic", lambda: _call_anthropic_fc(os.environ.get("ANTHROPIC_API_KEY"), prompt)),
        ("OpenAI", lambda: _call_openai_fc(os.environ.get("OPENAI_API_KEY"), prompt)),
    ]:
        try:
            result_text = call_fn()
            if result_text:
                print(f"[SEARCH-INST] {provider} succeeded")
                break
        except Exception as e:
            print(f"[SEARCH-INST] {provider} failed: {e}")

    if not result_text:
        return []

    text = result_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        items = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", text)
        if match:
            items = json.loads(match.group())
        else:
            return []

    if not isinstance(items, list):
        return []

    return [
        InstitutionResult(
            name=item.get("name", ""),
            affiliation=item.get("affiliation", ""),
            country=item.get("country", ""),
        )
        for item in items[:5]
        if isinstance(item, dict) and item.get("name")
    ]


class SubjectSearchRequest(PydanticBase):
    query: str
    institution_type: str = "university"
    institution_name: Optional[str] = None
    course: Optional[str] = None
    affiliation: Optional[str] = None


class SubjectSearchResult(PydanticBase):
    name: str
    code: Optional[str] = None


@router.post("/search-subjects", response_model=TList[SubjectSearchResult])
def search_subjects(
    body: SubjectSearchRequest,
    current_user: User = Depends(get_current_user),
):
    import os, json, re

    query = body.query.strip()
    if len(query) < 2:
        return []

    context_parts = [f"Institution type: {body.institution_type.replace('_', ' ').title()}"]
    if body.institution_name:
        context_parts.append(f"Institution: {body.institution_name}")
    if body.affiliation:
        context_parts.append(f"Affiliation: {body.affiliation}")
    if body.course:
        context_parts.append(f"Course: {body.course}")

    context = "\n".join(context_parts)

    prompt = f"""You are an education expert. A student is searching for a subject/module to add to their study tracker.

Context:
{context}

Search query: "{query}"

Return up to 8 real subjects/modules matching this search query that a student in this context would actually study.

ACCURACY IS CRITICAL:
- Use REAL subject names as they appear in actual course catalogues and syllabi
- For "code": only include it if you are CONFIDENT it is the real official code. Set to null if unsure. Do NOT guess or invent codes.
- Well-known codes you can use: CIE A-Level (Maths=9709, Physics=9702, Chemistry=9701, Biology=9700, CS=9618, Economics=9708), GCSE AQA (Maths=8300, English=8700, CS=8525)
- For university modules: return null for code unless you genuinely know it. Hallucinated codes are worse than no code.

Return ONLY a JSON array: [{{"name": "Full Subject Name", "code": "CODE_OR_NULL"}}]"""

    result_text = None
    for provider, call_fn in [
        ("Groq", lambda: _call_groq_fc(os.environ.get("GROQ_API_KEY"), prompt)),
        ("Anthropic", lambda: _call_anthropic_fc(os.environ.get("ANTHROPIC_API_KEY"), prompt)),
        ("OpenAI", lambda: _call_openai_fc(os.environ.get("OPENAI_API_KEY"), prompt)),
    ]:
        try:
            result_text = call_fn()
            if result_text:
                break
        except Exception as e:
            print(f"[SEARCH-SUBJECTS] {provider} failed: {e}")

    if not result_text:
        return []

    text = result_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        items = json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\[[\s\S]*\]", text)
        if match:
            items = json.loads(match.group())
        else:
            return []

    if not isinstance(items, list):
        return []

    return [
        SubjectSearchResult(name=item["name"], code=item.get("code"))
        for item in items[:8]
        if isinstance(item, dict) and item.get("name")
    ]


class SubjectSuggestRequest(PydanticBase):
    institution_type: str          # school, college, sixth_form, university
    institution_name: Optional[str] = None
    course: Optional[str] = None
    year_of_study: Optional[int] = None
    degree_level: Optional[str] = None   # undergraduate, masters, phd
    affiliation: Optional[str] = None    # e.g., "Affiliated with London Metropolitan University"


class SuggestedSubject(PydanticBase):
    name: str
    code: Optional[str] = None
    color: str = "#fea9d3"


@router.post("/suggest-subjects", response_model=TList[SuggestedSubject])
def suggest_subjects(
    body: SubjectSuggestRequest,
    current_user: User = Depends(get_current_user),
):
    import os, json, re

    # Build a context-aware prompt
    inst_type = body.institution_type.replace("_", " ").title()
    parts = [f"Institution type: {inst_type}"]
    if body.institution_name:
        parts.append(f"Institution name: {body.institution_name}")
    if body.affiliation:
        parts.append(f"University affiliation: {body.affiliation}")
    if body.degree_level:
        parts.append(f"Degree level: {body.degree_level}")
    if body.course:
        parts.append(f"Course/Program/Stream: {body.course}")
    if body.year_of_study:
        parts.append(f"Year of study: {body.year_of_study}")

    context = "\n".join(parts)

    prompt = f"""You are an education expert. A student provided:

{context}

Suggest 8-12 subjects/modules they are most likely studying RIGHT NOW based on their course, year and institution.

ACCURACY IS CRITICAL — this is a real app used by real students:
- Only suggest subjects you are CONFIDENT actually exist in this type of programme
- Use the REAL, OFFICIAL subject/module names as they appear in actual course catalogues
- For the "code" field: include the official module/subject code ONLY if you are confident it is correct. If you are NOT sure of the exact code, set "code" to null. Do NOT invent or guess codes.
- Well-known standardised codes you CAN use confidently:
  * CIE A-Level: Mathematics=9709, Physics=9702, Chemistry=9701, Biology=9700, Computer Science=9618, Economics=9708, Business=9609, Psychology=9990, English Language=9093, Further Maths=9231, Accounting=9706, Sociology=9699
  * Edexcel A-Level: Maths=8MA0/9MA0, Physics=9PH0, Chemistry=9CH0, Biology=9BN0
  * GCSE (AQA): Maths=8300, English Lang=8700, Combined Sci=8464, Physics=8463, CS=8525
- For university modules: only include codes if you genuinely know them from the specific university. Most LLMs do NOT reliably know university module codes — it is MUCH better to return null than to hallucinate a fake code.
- Focus on getting the SUBJECT NAMES right — those matter most to students.
- Include a hex color for each from: #fea9d3, #ddf6ff, #98a869, #f7aeae, #ffbc5c, #e4bc83, #ffd5f5, #ef6262, #58772f, #fdefdb

Return ONLY a JSON array. Each item: {{"name": "string", "code": "string or null", "color": "hex string"}}

Example:
[
  {{"name": "Mathematics", "code": "9709", "color": "#ddf6ff"}},
  {{"name": "Web Development", "code": null, "color": "#98a869"}}
]"""

    # Try AI providers in order (same pattern as flashcard generation)
    result_text = None
    for provider, call_fn in [
        ("Groq", lambda: _call_groq_fc(os.environ.get("GROQ_API_KEY"), prompt)),
        ("Anthropic", lambda: _call_anthropic_fc(os.environ.get("ANTHROPIC_API_KEY"), prompt)),
        ("OpenAI", lambda: _call_openai_fc(os.environ.get("OPENAI_API_KEY"), prompt)),
    ]:
        try:
            result_text = call_fn()
            if result_text:
                print(f"[SUGGEST-SUBJECTS] {provider} succeeded")
                break
        except Exception as e:
            print(f"[SUGGEST-SUBJECTS] {provider} failed: {e}")

    if not result_text:
        # Fallback: return sensible defaults based on institution type
        return _fallback_subjects(body)

    # Parse the JSON response
    text = result_text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    try:
        subjects = json.loads(text)
    except json.JSONDecodeError:
        # Try to extract JSON array
        match = re.search(r"\[[\s\S]*\]", text)
        if match:
            subjects = json.loads(match.group())
        else:
            return _fallback_subjects(body)

    if not isinstance(subjects, list):
        return _fallback_subjects(body)

    # Normalize and return
    result = []
    for s in subjects[:12]:
        if isinstance(s, dict) and "name" in s:
            result.append(SuggestedSubject(
                name=s["name"],
                code=s.get("code"),
                color=s.get("color", "#fea9d3"),
            ))
    return result if result else _fallback_subjects(body)


def _fallback_subjects(body: SubjectSuggestRequest) -> list:
    colors = ["#fea9d3", "#ddf6ff", "#98a869", "#f7aeae", "#ffbc5c",
              "#e4bc83", "#ffd5f5", "#ef6262", "#58772f", "#fdefdb"]

    t = body.institution_type.lower()
    if t in ("school", "secondary"):
        # GCSE AQA codes — well-known and standardised
        subjects = [
            ("Mathematics", "8300"), ("English Language", "8700"), ("Combined Science", "8464"),
            ("History", "8145"), ("Geography", "8035"), ("Computer Science", "8525"),
            ("Physical Education", None), ("Art & Design", None),
        ]
    elif t in ("sixth_form", "a_levels", "college") and body.course and "a level" in body.course.lower():
        # CIE A-Level codes — well-known and standardised
        subjects = [
            ("Mathematics", "9709"), ("Further Mathematics", "9231"),
            ("Physics", "9702"), ("Chemistry", "9701"),
            ("Biology", "9700"), ("Computer Science", "9618"),
            ("Economics", "9708"), ("Psychology", "9990"),
            ("Business", "9609"), ("English Language", "9093"),
        ]
    elif t in ("sixth_form", "college"):
        subjects = [
            ("Mathematics", "9709"), ("English Language", "9093"),
            ("Physics", "9702"), ("Chemistry", "9701"),
            ("Biology", "9700"), ("Computer Science", "9618"),
            ("Business Studies", "9609"), ("Economics", "9708"),
        ]
    elif t == "university":
        # University modules vary too much — don't guess codes
        subjects = [
            ("Programming Fundamentals", None), ("Web Development", None),
            ("Database Systems", None), ("Computer Networks", None),
            ("Software Engineering", None), ("Data Structures & Algorithms", None),
            ("Operating Systems", None), ("Research Methods", None),
        ]
    else:
        subjects = [
            ("Mathematics", None), ("English", None), ("Science", None),
            ("History", None), ("Geography", None), ("Art", None),
        ]

    return [
        SuggestedSubject(name=name, code=code, color=colors[i % len(colors)])
        for i, (name, code) in enumerate(subjects)
    ]
