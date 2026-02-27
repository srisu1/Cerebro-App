from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID

from app.database import get_db
from app.models.user import User
from app.models.study import Subject, StudySession, Quiz, Flashcard, FlashcardDeck
from app.schemas.study import (
    SubjectCreate, SubjectResponse, SubjectUpdate,
    StudySessionCreate, StudySessionResponse, StudySessionUpdate,
    QuizCreate, QuizResponse,
    FlashcardDeckCreate, FlashcardDeckUpdate, FlashcardDeckResponse,
    FlashcardCreate, FlashcardResponse, FlashcardReview,
)
from app.utils.auth import get_current_user

router = APIRouter(prefix="/study", tags=["study"])


# --- subjects ---

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
    return subject


@router.get("/subjects", response_model=List[SubjectResponse])
def list_subjects(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Subject).filter(Subject.user_id == current_user.id).all()


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
    return subject


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
    return subject


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


# --- study sessions ---

@router.post("/sessions", response_model=StudySessionResponse, status_code=status.HTTP_201_CREATED)
def create_study_session(
    data: StudySessionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # calculate xp: 25 per 30 min, bonus for high focus
    xp_earned = int(data.duration_minutes / 30) * 25
    if data.focus_score and data.focus_score >= 80:
        xp_earned = int(xp_earned * 1.25)

    session = StudySession(
        user_id=current_user.id,
        xp_earned=xp_earned,
        **data.model_dump(),
    )
    db.add(session)

    current_user.total_xp += xp_earned
    current_user.level = (current_user.total_xp // 500) + 1

    db.commit()
    db.refresh(session)
    return session


@router.get("/sessions", response_model=List[StudySessionResponse])
def list_study_sessions(
    subject_id: Optional[UUID] = Query(None),
    limit: int = Query(default=20, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(StudySession).filter(StudySession.user_id == current_user.id)
    if subject_id:
        query = query.filter(StudySession.subject_id == subject_id)
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

    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(session, field, value)

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

    # revert xp
    current_user.total_xp = max(0, current_user.total_xp - session.xp_earned)
    current_user.level = (current_user.total_xp // 500) + 1

    db.delete(session)
    db.commit()


# --- quizzes ---

@router.post("/quizzes", response_model=QuizResponse, status_code=status.HTTP_201_CREATED)
def create_quiz(
    data: QuizCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = Quiz(user_id=current_user.id, **data.model_dump())
    db.add(quiz)

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
    limit: int = Query(default=20, le=100),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(Quiz).filter(Quiz.user_id == current_user.id)
    if subject_id:
        query = query.filter(Quiz.subject_id == subject_id)
    return query.order_by(Quiz.date_taken.desc()).limit(limit).all()


@router.delete("/quizzes/{quiz_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_quiz(
    quiz_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = db.query(Quiz).filter(Quiz.id == quiz_id, Quiz.user_id == current_user.id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    percentage = float(quiz.score_achieved / quiz.max_score * 100) if quiz.max_score > 0 else 0
    xp_to_remove = 15 if percentage >= 70 else 5
    current_user.total_xp = max(0, current_user.total_xp - xp_to_remove)
    current_user.level = (current_user.total_xp // 500) + 1
    db.delete(quiz)
    db.commit()


# --- flashcard decks ---

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
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # auto-migrate orphan cards into an "unsorted" deck
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
    result["flashcards"] = [
        {"id": c.id, "front_text": c.front_text, "back_text": c.back_text,
         "tags": c.tags, "difficulty": c.difficulty, "ease_factor": float(c.ease_factor),
         "repetitions": c.repetitions, "interval_days": c.interval_days,
         "next_review_date": c.next_review_date.isoformat() if c.next_review_date else None,
         "total_reviews": c.total_reviews, "correct_reviews": c.correct_reviews,
         "streak_days": c.streak_days, "created_at": c.created_at.isoformat() if c.created_at else None}
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
    for field, value in updates.model_dump(exclude_unset=True).items():
        setattr(deck, field, value)
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


# --- flashcards ---

@router.post("/flashcards", response_model=FlashcardResponse, status_code=status.HTTP_201_CREATED)
def create_flashcard(
    data: FlashcardCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    card = Flashcard(user_id=current_user.id, **data.model_dump())
    db.add(card)
    db.commit()
    db.refresh(card)
    return card


@router.get("/flashcards", response_model=List[FlashcardResponse])
def list_flashcards(
    subject_id: Optional[UUID] = Query(None),
    due_only: bool = Query(default=False),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    from datetime import date

    query = db.query(Flashcard).filter(Flashcard.user_id == current_user.id)
    if subject_id:
        query = query.filter(Flashcard.subject_id == subject_id)
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
    from datetime import date, timedelta
    from decimal import Decimal

    card = db.query(Flashcard).filter(
        Flashcard.id == card_id,
        Flashcard.user_id == current_user.id,
    ).first()
    if not card:
        raise HTTPException(status_code=404, detail="Flashcard not found")

    q = review.quality

    # SM-2 algorithm
    if q >= 3:
        if card.repetitions == 0:
            card.interval_days = 1
        elif card.repetitions == 1:
            card.interval_days = 6
        else:
            card.interval_days = int(card.interval_days * float(card.ease_factor))

        card.repetitions += 1
        card.correct_reviews += 1
    else:
        card.repetitions = 0
        card.interval_days = 1

    # update ease factor
    new_ef = float(card.ease_factor) + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    card.ease_factor = Decimal(str(max(1.3, new_ef)))

    card.last_review_date = date.today()
    card.next_review_date = date.today() + timedelta(days=card.interval_days)
    card.total_reviews += 1

    # xp for review
    current_user.total_xp += 5
    current_user.level = (current_user.total_xp // 500) + 1

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
