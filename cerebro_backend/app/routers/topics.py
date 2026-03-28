from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from typing import List
from uuid import UUID

from app.database import get_db
from app.models.user import User
from app.models.study import (
    Subject, StudySession, Quiz, Flashcard, FlashcardDeck,
)
from app.models.quiz_engine import StudyMaterial, GeneratedQuiz
from app.models.topic import (
    Topic, normalize_topic_name,
    material_topics, session_topics, deck_topics,
    flashcard_topics, quiz_topics, generated_quiz_topics,
)
from app.schemas.topic import (
    TopicCreate, TopicUpdate, TopicResponse, TopicAttach,
)
from app.utils.auth import get_current_user


router = APIRouter(prefix="/study", tags=["study-topics"])


#  Internal helpers — also used by other routers.

def _ensure_subject_owned(db: Session, subject_id: UUID, user: User) -> Subject:
    subject = db.query(Subject).filter(
        Subject.id == subject_id,
        Subject.user_id == user.id,
    ).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")
    return subject


def _ensure_topic_owned(db: Session, topic_id: UUID, user: User) -> Topic:
    topic = db.query(Topic).filter(
        Topic.id == topic_id,
        Topic.user_id == user.id,
    ).first()
    if not topic:
        raise HTTPException(status_code=404, detail="Topic not found")
    return topic


def resolve_topics_from_names(
    db: Session,
    user: User,
    subject_id: UUID,
    names: List[str],
) -> List[Topic]:
    if not names or subject_id is None:
        return []

    # Verify subject ownership up-front (one lookup).
    _ensure_subject_owned(db, subject_id, user)

    seen_keys = set()
    resolved: List[Topic] = []

    for raw in names:
        key = normalize_topic_name(raw)
        if not key or key in seen_keys:
            continue
        seen_keys.add(key)

        topic = db.query(Topic).filter(
            Topic.user_id == user.id,
            Topic.subject_id == subject_id,
            Topic.name_key == key,
        ).first()

        if not topic:
            topic = Topic(
                user_id=user.id,
                subject_id=subject_id,
                name=str(raw).strip(),
                name_key=key,
                color="#B5C4A0",
            )
            db.add(topic)
            db.flush()  # get topic.id before commit

        resolved.append(topic)

    return resolved


def _topic_to_response(db: Session, topic: Topic) -> TopicResponse:
    materials_count = db.query(func.count()).select_from(material_topics).where(
        material_topics.c.topic_id == topic.id).scalar() or 0
    sessions_count = db.query(func.count()).select_from(session_topics).where(
        session_topics.c.topic_id == topic.id).scalar() or 0
    decks_count = db.query(func.count()).select_from(deck_topics).where(
        deck_topics.c.topic_id == topic.id).scalar() or 0
    flashcards_count = db.query(func.count()).select_from(flashcard_topics).where(
        flashcard_topics.c.topic_id == topic.id).scalar() or 0
    quizzes_count = db.query(func.count()).select_from(quiz_topics).where(
        quiz_topics.c.topic_id == topic.id).scalar() or 0
    generated_quizzes_count = db.query(func.count()).select_from(generated_quiz_topics).where(
        generated_quiz_topics.c.topic_id == topic.id).scalar() or 0

    return TopicResponse(
        id=topic.id,
        subject_id=topic.subject_id,
        name=topic.name,
        color=topic.color,
        created_at=topic.created_at,
        updated_at=topic.updated_at,
        materials_count=materials_count,
        sessions_count=sessions_count,
        decks_count=decks_count,
        flashcards_count=flashcards_count,
        quizzes_count=quizzes_count,
        generated_quizzes_count=generated_quizzes_count,
        total_items=(materials_count + sessions_count + decks_count
                     + flashcards_count + quizzes_count + generated_quizzes_count),
    )


#  Endpoints

@router.get("/subjects/{subject_id}/topics", response_model=List[TopicResponse])
def list_topics_for_subject(
    subject_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _ensure_subject_owned(db, subject_id, current_user)

    topics = (
        db.query(Topic)
        .filter(Topic.user_id == current_user.id,
                Topic.subject_id == subject_id)
        .order_by(Topic.name)
        .all()
    )
    return [_topic_to_response(db, t) for t in topics]


@router.post("/topics", response_model=TopicResponse, status_code=status.HTTP_201_CREATED)
def create_topic(
    data: TopicCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _ensure_subject_owned(db, data.subject_id, current_user)

    key = normalize_topic_name(data.name)
    if not key:
        raise HTTPException(status_code=400, detail="Topic name cannot be empty")

    existing = db.query(Topic).filter(
        Topic.user_id == current_user.id,
        Topic.subject_id == data.subject_id,
        Topic.name_key == key,
    ).first()
    if existing:
        raise HTTPException(status_code=409,
                            detail=f"Topic '{existing.name}' already exists in this subject")

    topic = Topic(
        user_id=current_user.id,
        subject_id=data.subject_id,
        name=data.name.strip(),
        name_key=key,
        color=data.color,
    )
    db.add(topic)
    db.commit()
    db.refresh(topic)
    return _topic_to_response(db, topic)


@router.get("/topics/{topic_id}", response_model=TopicResponse)
def get_topic(
    topic_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    topic = _ensure_topic_owned(db, topic_id, current_user)
    return _topic_to_response(db, topic)


@router.put("/topics/{topic_id}", response_model=TopicResponse)
def update_topic(
    topic_id: UUID,
    data: TopicUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    topic = _ensure_topic_owned(db, topic_id, current_user)

    if data.name is not None:
        new_name = data.name.strip()
        new_key = normalize_topic_name(new_name)
        if not new_key:
            raise HTTPException(status_code=400, detail="Topic name cannot be empty")
        # Check collisions only if the key actually changed.
        if new_key != topic.name_key:
            collision = db.query(Topic).filter(
                Topic.user_id == current_user.id,
                Topic.subject_id == topic.subject_id,
                Topic.name_key == new_key,
                Topic.id != topic.id,
            ).first()
            if collision:
                raise HTTPException(
                    status_code=409,
                    detail=f"Topic '{collision.name}' already exists in this subject")
        topic.name = new_name
        topic.name_key = new_key

    if data.color is not None:
        topic.color = data.color

    db.commit()
    db.refresh(topic)
    return _topic_to_response(db, topic)


@router.delete("/topics/{topic_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_topic(
    topic_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    topic = _ensure_topic_owned(db, topic_id, current_user)
    db.delete(topic)
    db.commit()
    return None


#  Attach / detach

def _resolve_content_and_relationship(db: Session, user: User,
                                      content_type: str, content_id: UUID):
    mapping = {
        "material":       (StudyMaterial, "topics"),
        "session":        (StudySession, "topics"),
        "deck":           (FlashcardDeck, "topics"),
        "flashcard":      (Flashcard, "topics"),
        "quiz":           (Quiz, "topics"),
        "generated_quiz": (GeneratedQuiz, "topics"),
    }
    if content_type not in mapping:
        raise HTTPException(status_code=400, detail="Invalid content_type")
    model, rel = mapping[content_type]

    row = db.query(model).filter(
        model.id == content_id,
        model.user_id == user.id,
    ).first()
    if not row:
        raise HTTPException(status_code=404,
                            detail=f"{content_type} not found")
    return row, rel


@router.post("/topics/{topic_id}/attach", response_model=TopicResponse)
def attach_topic(
    topic_id: UUID,
    data: TopicAttach,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    topic = _ensure_topic_owned(db, topic_id, current_user)
    row, rel = _resolve_content_and_relationship(
        db, current_user, data.content_type, data.content_id)

    # Sanity: content must belong to the same subject as the topic.
    if getattr(row, "subject_id", None) and row.subject_id != topic.subject_id:
        raise HTTPException(
            status_code=400,
            detail="Topic's subject does not match the content item's subject")

    current = getattr(row, rel)
    if topic not in current:
        current.append(topic)
        db.commit()
    return _topic_to_response(db, topic)


@router.post("/topics/{topic_id}/detach", response_model=TopicResponse)
def detach_topic(
    topic_id: UUID,
    data: TopicAttach,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    topic = _ensure_topic_owned(db, topic_id, current_user)
    row, rel = _resolve_content_and_relationship(
        db, current_user, data.content_type, data.content_id)

    current = getattr(row, rel)
    if topic in current:
        current.remove(topic)
        db.commit()
    return _topic_to_response(db, topic)
