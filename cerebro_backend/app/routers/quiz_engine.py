from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Optional, List
import traceback
import tempfile
import os

from app.database import get_db
from app.models.user import User
from app.models.study import Subject, StudySession, Quiz, Flashcard, FlashcardDeck
from app.models.quiz_engine import StudyMaterial, GeneratedQuiz, QuizQuestion, QuizSchedule
from app.schemas.quiz_engine import (
    StudyMaterialCreate, StudyMaterialUpdate, StudyMaterialResponse,
    QuizGenerateRequest, GeneratedQuizResponse, GeneratedQuizDetail,
    GeneratedQuizForTaking, QuizQuestionForTaking,
    AnswerSubmit, QuizScheduleCreate, QuizScheduleResponse,
)
from app.utils.auth import get_current_user
from app.services.quiz_generator import generate_questions

router = APIRouter(prefix="/study", tags=["quiz-engine"])


# study materials

@router.post("/materials", status_code=status.HTTP_201_CREATED)
def create_material(
    data: StudyMaterialCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    word_count = len(data.content.split())
    material = StudyMaterial(
        user_id=current_user.id,
        word_count=word_count,
        **data.model_dump(),
    )
    db.add(material)
    db.commit()
    db.refresh(material)
    return _material_dict(material)


@router.get("/materials")
def list_materials(
    subject_id: Optional[UUID] = Query(None),
    limit: int = Query(default=50, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(StudyMaterial).filter(StudyMaterial.user_id == current_user.id)
    if subject_id:
        query = query.filter(StudyMaterial.subject_id == subject_id)
    materials = query.order_by(StudyMaterial.created_at.desc()).limit(limit).all()
    return [_material_dict(m) for m in materials]


@router.get("/materials/{material_id}")
def get_material(
    material_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    m = db.query(StudyMaterial).filter(
        StudyMaterial.id == material_id,
        StudyMaterial.user_id == current_user.id,
    ).first()
    if not m:
        raise HTTPException(status_code=404, detail="Material not found")
    return _material_dict(m)


@router.put("/materials/{material_id}")
def update_material(
    material_id: UUID,
    data: StudyMaterialUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    m = db.query(StudyMaterial).filter(
        StudyMaterial.id == material_id,
        StudyMaterial.user_id == current_user.id,
    ).first()
    if not m:
        raise HTTPException(status_code=404, detail="Material not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(m, field, value)
    if data.content is not None:
        m.word_count = len(data.content.split())
    db.commit()
    db.refresh(m)
    return _material_dict(m)


@router.delete("/materials/{material_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_material(
    material_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    m = db.query(StudyMaterial).filter(
        StudyMaterial.id == material_id,
        StudyMaterial.user_id == current_user.id,
    ).first()
    if not m:
        raise HTTPException(status_code=404, detail="Material not found")
    db.delete(m)
    db.commit()


@router.post("/materials/upload", status_code=status.HTTP_201_CREATED)
def upload_material(
    file: UploadFile = File(...),
    title: str = Form(...),
    subject_id: Optional[str] = Form(None),
    topics: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        filename = file.filename or "upload"
        ext = os.path.splitext(filename)[1].lower()

        file_bytes = file.file.read()
        print(f"[UPLOAD] File: {filename}, size: {len(file_bytes)} bytes, ext: {ext}")

        if ext == ".pdf":
            extracted = _extract_pdf_text(file_bytes)
            source_type = "pdf_upload"
        elif ext in (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff"):
            extracted = _extract_image_text(file_bytes, ext)
            source_type = "image_upload"
        elif ext in (".txt", ".md"):
            extracted = file_bytes.decode("utf-8", errors="replace")
            source_type = "pasted"
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported file type: {ext}. Use PDF, images (PNG/JPG), or text files."
            )

        extracted = _sanitize_text(extracted)

        if not extracted or len(extracted.strip()) < 5:
            extracted = f"[{ext.lstrip('.')} file uploaded: {filename}]"

        words = extracted.split()
        if len(words) > 50000:
            extracted = " ".join(words[:50000]) + "\n\n[... truncated — first 50,000 words stored]"

        print(f"[UPLOAD] Extracted {len(extracted.split())} words from {filename}")

        parsed_topics = []
        if topics:
            parsed_topics = [t.strip() for t in topics.split(",") if t.strip()]

        parsed_subject_id = None
        if subject_id and subject_id != "null" and subject_id != "":
            try:
                parsed_subject_id = UUID(subject_id)
            except ValueError:
                pass

        material = StudyMaterial(
            user_id=current_user.id,
            subject_id=parsed_subject_id,
            title=title or filename,
            content=extracted,
            source_type=source_type,
            topics=parsed_topics,
            word_count=len(extracted.split()),
        )
        db.add(material)
        db.commit()
        db.refresh(material)
        return _material_dict(material)

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"File upload failed: {str(e)}")


@router.post("/materials/import-sessions", status_code=status.HTTP_201_CREATED)
def import_session_notes(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        sessions = db.query(StudySession).filter(
            StudySession.user_id == current_user.id,
            StudySession.notes.isnot(None),
            StudySession.notes != "",
        ).order_by(StudySession.created_at.desc()).all()

        if not sessions:
            raise HTTPException(status_code=422, detail="No study sessions with notes found.")

        existing = set(
            m.title for m in db.query(StudyMaterial).filter(
                StudyMaterial.user_id == current_user.id,
                StudyMaterial.source_type == "session_import",
            ).all()
        )

        imported = []
        for s in sessions:
            session_title = f"Session: {s.title or 'Untitled'}"
            if session_title in existing:
                continue
            if not s.notes or len(s.notes.strip()) < 10:
                continue

            material = StudyMaterial(
                user_id=current_user.id,
                subject_id=s.subject_id,
                title=session_title,
                content=s.notes,
                source_type="session_import",
                topics=s.topics_covered or [],
                word_count=len(s.notes.split()),
            )
            db.add(material)
            imported.append(material)

        if not imported:
            raise HTTPException(status_code=422, detail="All session notes have already been imported.")

        db.commit()
        for m in imported:
            db.refresh(m)

        return {
            "imported_count": len(imported),
            "materials": [_material_dict(m) for m in imported],
        }

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Import failed: {str(e)}")


def _sanitize_text(text: str) -> str:
    text = text.replace('\x00', '')
    text = ''.join(c for c in text if c == '\n' or c == '\t' or c == '\r' or (ord(c) >= 32))
    return text


def _get_fitz():
    try:
        import pymupdf
        return pymupdf
    except ImportError:
        pass
    try:
        import fitz
        return fitz
    except ImportError:
        pass
    return None


def _extract_pdf_text(file_bytes: bytes) -> str:
    import io

    fitz = _get_fitz()

    # strategy 1: PyMuPDF direct text extraction
    if fitz:
        try:
            doc = fitz.open(stream=file_bytes, filetype="pdf")
            print(f"[PDF] Opened with PyMuPDF: {len(doc)} pages")
            text_parts = []
            for page in doc:
                page_text = page.get_text()
                if page_text and page_text.strip():
                    text_parts.append(page_text.strip())
            doc.close()
            text = _sanitize_text("\n\n".join(text_parts))
            if len(text.split()) > 30:
                print(f"[PDF] Text extraction: {len(text.split())} words from {len(text_parts)} pages")
                return text
            print(f"[PDF] Only {len(text.split())} words — trying OCR...")
        except Exception as e:
            print(f"[PDF] PyMuPDF text error: {e}")

    # strategy 2: pdfplumber
    try:
        import pdfplumber
        text_parts = []
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            for page in pdf.pages:
                page_text = page.extract_text()
                if page_text:
                    text_parts.append(page_text)
        text = _sanitize_text("\n\n".join(text_parts))
        if len(text.split()) > 30:
            print(f"[PDF] pdfplumber: {len(text.split())} words")
            return text
    except ImportError:
        pass
    except Exception as e:
        print(f"[PDF] pdfplumber error: {e}")

    # strategy 3: OCR for image-based PDFs
    if fitz:
        try:
            from PIL import Image
            import pytesseract
            print("[PDF] Attempting OCR on image-based PDF...")
            doc = fitz.open(stream=file_bytes, filetype="pdf")
            ocr_parts = []
            max_pages = min(len(doc), 30)
            for i in range(max_pages):
                page = doc[i]
                pix = page.get_pixmap(dpi=150)
                img_bytes = pix.tobytes("png")
                img = Image.open(io.BytesIO(img_bytes))
                page_text = pytesseract.image_to_string(img)
                if page_text and len(page_text.strip()) > 10:
                    ocr_parts.append(page_text.strip())
                if i % 10 == 0:
                    print(f"[PDF] OCR progress: page {i+1}/{max_pages}")
            doc.close()
            text = _sanitize_text("\n\n".join(ocr_parts))
            if len(text.split()) > 30:
                print(f"[PDF] OCR extracted {len(text.split())} words from {len(ocr_parts)} pages")
                return text
            else:
                print(f"[PDF] OCR only got {len(text.split())} words")
        except ImportError as e:
            print(f"[PDF] OCR not available (install tesseract + pytesseract): {e}")
        except Exception as e:
            print(f"[PDF] OCR error: {e}")

    return "[PDF uploaded — this appears to be an image-based PDF. Install tesseract for OCR: brew install tesseract]"


def _extract_image_text(file_bytes: bytes, ext: str) -> str:
    import io
    try:
        from PIL import Image
        img = Image.open(io.BytesIO(file_bytes))
        try:
            import pytesseract
            text = pytesseract.image_to_string(img)
            if text and len(text.strip()) >= 10:
                return text
        except ImportError:
            print("WARNING: pytesseract not installed. Run: pip install pytesseract")
        except Exception as e:
            print(f"OCR error: {e}")
    except ImportError:
        print("WARNING: Pillow not installed. Run: pip install Pillow")
    except Exception as e:
        print(f"Image open error: {e}")

    return "[Image uploaded — OCR not available, install pytesseract & Pillow]"


def _material_dict(m: StudyMaterial) -> dict:
    return {
        "id": str(m.id),
        "user_id": str(m.user_id),
        "subject_id": str(m.subject_id) if m.subject_id else None,
        "title": m.title,
        "content": m.content,
        "source_type": m.source_type,
        "topics": m.topics or [],
        "word_count": m.word_count or 0,
        "created_at": m.created_at.isoformat() if m.created_at else None,
        "updated_at": m.updated_at.isoformat() if m.updated_at else None,
    }


# quiz generation

@router.post("/generate-quiz")
def generate_quiz(
    data: QuizGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        materials = db.query(StudyMaterial).filter(
            StudyMaterial.id.in_(data.material_ids),
            StudyMaterial.user_id == current_user.id,
        ).all()

        if not materials:
            raise HTTPException(status_code=404, detail="No matching materials found")

        combined_content = "\n\n".join([
            f"=== {m.title} ===\n{m.content}" for m in materials
        ])

        print(f"\n[QUIZ-GEN] Materials: {len(materials)}")
        for m in materials:
            content_preview = (m.content or "")[:200].replace('\n', ' ')
            print(f"[QUIZ-GEN]   '{m.title}': {m.word_count} words, preview: {content_preview}")
        print(f"[QUIZ-GEN] Combined content length: {len(combined_content)} chars, ~{len(combined_content.split())} words")

        all_topics = []
        for m in materials:
            all_topics.extend(m.topics or [])

        # enhance with flashcard weak topics
        try:
            weak_fc_tags = []
            subject_ids = list(set(m.subject_id for m in materials if m.subject_id))
            if subject_ids:
                weak_cards = db.query(Flashcard).filter(
                    Flashcard.user_id == current_user.id,
                    Flashcard.subject_id.in_(subject_ids),
                    Flashcard.total_reviews > 2,
                ).all()
                for c in weak_cards:
                    if c.total_reviews > 0 and (c.correct_reviews / c.total_reviews) < 0.6:
                        weak_fc_tags.extend(c.tags or [])
            if weak_fc_tags:
                print(f"[QUIZ-GEN] Adding {len(set(weak_fc_tags))} weak flashcard topics: {list(set(weak_fc_tags))[:5]}")
                all_topics.extend(weak_fc_tags)
        except Exception as e:
            print(f"[QUIZ-GEN] Flashcard weak topic detection skipped: {e}")

        all_topics = list(set(all_topics))

        questions, source = generate_questions(
            content=combined_content,
            question_count=data.question_count,
            question_types=data.question_types,
            difficulty=data.difficulty,
            topics=all_topics or None,
        )

        print(f"[QUIZ-GEN] Generated {len(questions)} questions via '{source}'")
        for i, q in enumerate(questions[:3]):
            print(f"[QUIZ-GEN]   Q{i}: [{q.get('type')}] {q.get('question','')[:80]}")

        if not questions:
            if source == "no_api_key":
                raise HTTPException(
                    status_code=422,
                    detail="No AI API key configured. The quiz generator needs an AI model "
                           "to create smart questions. Get a FREE Groq API key at console.groq.com, "
                           "then restart your backend with: "
                           "GROQ_API_KEY=your_key uvicorn app.main:app --reload"
                )
            raise HTTPException(
                status_code=422,
                detail="Could not generate questions from the provided material. "
                       "Try adding more detailed notes."
            )

        title = data.title or f"Quiz: {materials[0].title}"
        if len(materials) > 1:
            title = data.title or f"Quiz: {len(materials)} materials"

        subject_id = data.subject_id or materials[0].subject_id

        quiz = GeneratedQuiz(
            user_id=current_user.id,
            subject_id=subject_id,
            title=title,
            quiz_type="practice",
            source=source,
            material_ids=[m.id for m in materials],
            topic_focus=all_topics[:10],
            total_questions=len(questions),
            time_limit_minutes=data.time_limit_minutes,
            status="pending",
            max_score=Decimal(str(len(questions))),
        )
        db.add(quiz)
        db.flush()

        for i, q_data in enumerate(questions):
            question = QuizQuestion(
                quiz_id=quiz.id,
                question_type=q_data.get("type", "mcq"),
                question_text=q_data.get("question", ""),
                options=q_data.get("options", []),
                correct_answer=q_data.get("correct_answer", ""),
                explanation=q_data.get("explanation"),
                topic=q_data.get("topic"),
                difficulty=q_data.get("difficulty", 3),
                order_index=q_data.get("order_index", i),
            )
            db.add(question)

        db.commit()
        db.refresh(quiz)

        return _quiz_detail_dict(quiz)

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Quiz generation failed: {str(e)}")


# quiz taking

@router.post("/generated-quizzes/{quiz_id}/start")
def start_quiz(
    quiz_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = _get_user_quiz(quiz_id, current_user.id, db)
    if quiz.status not in ("pending", "abandoned"):
        raise HTTPException(status_code=400, detail=f"Quiz is already {quiz.status}")
    quiz.status = "in_progress"
    quiz.started_at = datetime.now(timezone.utc)
    for q in quiz.questions:
        q.user_answer = None
        q.is_correct = None
    quiz.correct_count = 0
    quiz.score_achieved = None
    db.commit()
    db.refresh(quiz)
    return _quiz_detail_dict(quiz)


@router.post("/generated-quizzes/{quiz_id}/answer")
def answer_question(
    quiz_id: UUID,
    data: AnswerSubmit,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = _get_user_quiz(quiz_id, current_user.id, db)
    if quiz.status != "in_progress":
        raise HTTPException(status_code=400, detail="Quiz is not in progress")

    question = db.query(QuizQuestion).filter(
        QuizQuestion.id == data.question_id,
        QuizQuestion.quiz_id == quiz_id,
    ).first()
    if not question:
        raise HTTPException(status_code=404, detail="Question not found")

    question.user_answer = data.user_answer

    if question.question_type == "fill_blank":
        question.is_correct = _fuzzy_match(data.user_answer, question.correct_answer)
    else:
        question.is_correct = data.user_answer.strip().lower() == question.correct_answer.strip().lower()

    db.commit()

    return {
        "question_id": str(question.id),
        "user_answer": question.user_answer,
        "is_correct": question.is_correct,
        "correct_answer": question.correct_answer,
        "explanation": question.explanation,
    }


@router.post("/generated-quizzes/{quiz_id}/complete")
def complete_quiz(
    quiz_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = _get_user_quiz(quiz_id, current_user.id, db)
    if quiz.status != "in_progress":
        raise HTTPException(status_code=400, detail="Quiz is not in progress")

    correct = sum(1 for q in quiz.questions if q.is_correct)
    total = len(quiz.questions)
    quiz.correct_count = correct
    quiz.score_achieved = Decimal(str(correct))
    quiz.max_score = Decimal(str(total))
    quiz.status = "completed"
    quiz.completed_at = datetime.now(timezone.utc)

    # award XP
    percentage = (correct / total * 100) if total > 0 else 0
    xp = 20 if percentage >= 80 else (15 if percentage >= 60 else 10)
    quiz.xp_earned = xp
    current_user.total_xp += xp
    current_user.level = (current_user.total_xp // 500) + 1

    # log to existing Quiz model for analytics
    weak_topics = list(set(
        q.topic for q in quiz.questions
        if q.is_correct is False and q.topic
    ))
    topics_tested = list(set(
        q.topic for q in quiz.questions if q.topic
    ))

    legacy_quiz = Quiz(
        user_id=current_user.id,
        subject_id=quiz.subject_id,
        title=quiz.title,
        quiz_type=quiz.quiz_type,
        score_achieved=quiz.score_achieved,
        max_score=quiz.max_score,
        topics_tested=topics_tested,
        weak_topics=weak_topics,
        date_taken=quiz.completed_at.date(),
    )
    db.add(legacy_quiz)

    # auto-generate flashcards from wrong answers
    wrong_questions = [q for q in quiz.questions if q.is_correct is False]
    cards_created = 0
    if wrong_questions:
        try:
            deck_name = f"Quiz Review: {quiz.title[:80]}"
            review_deck = db.query(FlashcardDeck).filter(
                FlashcardDeck.user_id == current_user.id,
                FlashcardDeck.name == deck_name,
            ).first()
            if not review_deck:
                review_deck = FlashcardDeck(
                    user_id=current_user.id,
                    subject_id=quiz.subject_id,
                    name=deck_name,
                    description=f"Auto-generated from wrong answers in '{quiz.title}'",
                    color="#F0A898",
                    icon="quiz",
                )
                db.add(review_deck)
                db.flush()

            from datetime import date as _date
            for wq in wrong_questions:
                back = wq.correct_answer or ""
                if wq.explanation:
                    back += f"\n\n{wq.explanation}"
                card = Flashcard(
                    user_id=current_user.id,
                    subject_id=quiz.subject_id,
                    deck_id=review_deck.id,
                    front_text=wq.question_text,
                    back_text=back.strip(),
                    tags=[wq.topic] if wq.topic else [],
                    difficulty=min(5, max(1, wq.difficulty or 3)),
                )
                db.add(card)
                cards_created += 1
            print(f"[QUIZ-FC] Created {cards_created} flashcards from wrong answers in '{quiz.title}'")
        except Exception as e:
            print(f"[QUIZ-FC] Failed to auto-create flashcards: {e}")

    db.commit()
    db.refresh(quiz)

    result = _quiz_detail_dict(quiz)
    result["flashcards_created"] = cards_created
    return result


# quiz history

@router.get("/generated-quizzes")
def list_generated_quizzes(
    status_filter: Optional[str] = Query(None, alias="status"),
    subject_id: Optional[UUID] = Query(None),
    limit: int = Query(default=50, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = db.query(GeneratedQuiz).filter(GeneratedQuiz.user_id == current_user.id)
    if status_filter:
        query = query.filter(GeneratedQuiz.status == status_filter)
    if subject_id:
        query = query.filter(GeneratedQuiz.subject_id == subject_id)
    quizzes = query.order_by(GeneratedQuiz.created_at.desc()).limit(limit).all()
    return [_quiz_response_dict(q) for q in quizzes]


@router.get("/generated-quizzes/{quiz_id}")
def get_generated_quiz(
    quiz_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = _get_user_quiz(quiz_id, current_user.id, db)
    return _quiz_detail_dict(quiz)


@router.delete("/generated-quizzes/{quiz_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_generated_quiz(
    quiz_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    quiz = _get_user_quiz(quiz_id, current_user.id, db)
    if quiz.xp_earned:
        current_user.total_xp = max(0, current_user.total_xp - quiz.xp_earned)
        current_user.level = (current_user.total_xp // 500) + 1
    db.delete(quiz)
    db.commit()


# quiz scheduling

@router.get("/quiz-schedule")
def get_quiz_schedule(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    schedule = db.query(QuizSchedule).filter(
        QuizSchedule.user_id == current_user.id
    ).first()
    if not schedule:
        return None
    return _schedule_dict(schedule)


@router.post("/quiz-schedule")
def create_or_update_schedule(
    data: QuizScheduleCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    schedule = db.query(QuizSchedule).filter(
        QuizSchedule.user_id == current_user.id
    ).first()

    if schedule:
        for field, value in data.model_dump().items():
            setattr(schedule, field, value)
    else:
        schedule = QuizSchedule(user_id=current_user.id, **data.model_dump())
        db.add(schedule)

    schedule.next_due_at = _calculate_next_due(data.frequency, data.day_of_week)

    db.commit()
    db.refresh(schedule)
    return _schedule_dict(schedule)


@router.post("/quiz-schedule/generate-now")
def generate_scheduled_quiz(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        schedule = db.query(QuizSchedule).filter(
            QuizSchedule.user_id == current_user.id
        ).first()

        question_count = schedule.question_count if schedule else 10
        question_types = schedule.question_types if schedule else ["mcq", "true_false", "fill_blank"]

        materials = db.query(StudyMaterial).filter(
            StudyMaterial.user_id == current_user.id
        ).all()

        if not materials:
            raise HTTPException(status_code=422, detail="No study materials found. Add some materials first!")

        weak_topics = _detect_weak_topics(current_user.id, db)

        combined_content = "\n\n".join([
            f"=== {m.title} ===\n{m.content}" for m in materials
        ])

        questions, source = generate_questions(
            content=combined_content,
            question_count=question_count,
            question_types=question_types,
            topics=weak_topics or None,
        )

        if not questions:
            raise HTTPException(status_code=422, detail="Could not generate questions. Try adding more study materials.")

        quiz_type = schedule.frequency if schedule else "practice"
        title = f"{'Weekly' if quiz_type == 'weekly' else 'Biweekly' if quiz_type == 'biweekly' else 'Monthly'} Review Quiz"

        quiz = GeneratedQuiz(
            user_id=current_user.id,
            title=title,
            quiz_type=quiz_type,
            source=source,
            material_ids=[m.id for m in materials],
            topic_focus=weak_topics[:10],
            total_questions=len(questions),
            status="pending",
            max_score=Decimal(str(len(questions))),
        )
        db.add(quiz)
        db.flush()

        for i, q_data in enumerate(questions):
            question = QuizQuestion(
                quiz_id=quiz.id,
                question_type=q_data.get("type", "mcq"),
                question_text=q_data.get("question", ""),
                options=q_data.get("options", []),
                correct_answer=q_data.get("correct_answer", ""),
                explanation=q_data.get("explanation"),
                topic=q_data.get("topic"),
                difficulty=q_data.get("difficulty", 3),
                order_index=i,
            )
            db.add(question)

        if schedule:
            schedule.last_generated_at = datetime.now(timezone.utc)
            schedule.next_due_at = _calculate_next_due(schedule.frequency, schedule.day_of_week)

        db.commit()
        db.refresh(quiz)

        return _quiz_detail_dict(quiz)

    except HTTPException:
        raise
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# helpers

def _get_user_quiz(quiz_id: UUID, user_id, db: Session) -> GeneratedQuiz:
    quiz = db.query(GeneratedQuiz).filter(
        GeneratedQuiz.id == quiz_id,
        GeneratedQuiz.user_id == user_id,
    ).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="Quiz not found")
    return quiz


def _fuzzy_match(user_answer: str, correct_answer: str) -> bool:
    ua = user_answer.strip().lower()
    ca = correct_answer.strip().lower()
    if not ua or not ca:
        return False

    if ua == ca:
        return True

    def _clean(s):
        s = s.replace("the ", "").replace("a ", "").replace("an ", "")
        s = ''.join(c for c in s if c.isalnum() or c == ' ')
        return ' '.join(s.split()).strip()

    ua_c = _clean(ua)
    ca_c = _clean(ca)
    if ua_c == ca_c:
        return True

    def _stem(s):
        if s.endswith('ies'): return s[:-3] + 'y'
        if s.endswith('es'): return s[:-2]
        if s.endswith('s') and not s.endswith('ss'): return s[:-1]
        return s

    if _stem(ua_c) == _stem(ca_c):
        return True

    if len(ua_c) >= 3 and len(ca_c) >= 3:
        if ua_c in ca_c or ca_c in ua_c:
            shorter = min(len(ua_c), len(ca_c))
            longer = max(len(ua_c), len(ca_c))
            if shorter >= longer * 0.6:
                return True

    def _levenshtein(s1, s2):
        if len(s1) < len(s2): s1, s2 = s2, s1
        if not s2: return len(s1)
        prev = list(range(len(s2) + 1))
        for i, c1 in enumerate(s1):
            curr = [i + 1]
            for j, c2 in enumerate(s2):
                curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (0 if c1 == c2 else 1)))
            prev = curr
        return prev[-1]

    dist = _levenshtein(ua_c, ca_c)
    max_len = max(len(ua_c), len(ca_c))
    if max_len > 0 and dist <= max(2, max_len * 0.25):
        return True

    _SYNONYMS = {
        frozenset({'villain', 'antagonist', 'adversary', 'foe', 'enemy', 'nemesis', 'rival'}),
        frozenset({'hero', 'protagonist', 'main character', 'lead'}),
        frozenset({'happy', 'joyful', 'cheerful', 'glad', 'content', 'pleased', 'elated'}),
        frozenset({'sad', 'unhappy', 'sorrowful', 'melancholy', 'gloomy', 'depressed', 'dejected'}),
        frozenset({'big', 'large', 'huge', 'enormous', 'massive', 'immense', 'vast', 'gigantic'}),
        frozenset({'small', 'tiny', 'little', 'minute', 'miniature', 'compact', 'petite'}),
        frozenset({'fast', 'quick', 'rapid', 'swift', 'speedy', 'hasty'}),
        frozenset({'slow', 'sluggish', 'gradual', 'leisurely', 'unhurried'}),
        frozenset({'important', 'significant', 'crucial', 'vital', 'essential', 'critical', 'key'}),
        frozenset({'unimportant', 'insignificant', 'trivial', 'negligible', 'minor'}),
        frozenset({'start', 'begin', 'commence', 'initiate', 'launch', 'onset'}),
        frozenset({'end', 'finish', 'conclude', 'terminate', 'complete', 'cease'}),
        frozenset({'increase', 'rise', 'grow', 'expand', 'escalate', 'surge', 'boost'}),
        frozenset({'decrease', 'decline', 'reduce', 'diminish', 'shrink', 'drop', 'lessen'}),
        frozenset({'cause', 'reason', 'source', 'origin', 'root', 'trigger', 'catalyst'}),
        frozenset({'effect', 'result', 'outcome', 'consequence', 'impact'}),
        frozenset({'help', 'assist', 'aid', 'support', 'facilitate'}),
        frozenset({'prevent', 'stop', 'hinder', 'block', 'inhibit', 'impede'}),
        frozenset({'show', 'demonstrate', 'illustrate', 'display', 'exhibit', 'reveal'}),
        frozenset({'hide', 'conceal', 'obscure', 'mask', 'cover'}),
        frozenset({'change', 'alter', 'modify', 'transform', 'shift', 'adjust'}),
        frozenset({'create', 'make', 'produce', 'generate', 'construct', 'build', 'form'}),
        frozenset({'destroy', 'demolish', 'ruin', 'eliminate', 'eradicate', 'annihilate'}),
        frozenset({'strong', 'powerful', 'robust', 'potent', 'mighty', 'forceful'}),
        frozenset({'weak', 'feeble', 'frail', 'fragile', 'delicate'}),
        frozenset({'true', 'correct', 'accurate', 'right', 'valid'}),
        frozenset({'false', 'incorrect', 'wrong', 'inaccurate', 'invalid'}),
        frozenset({'old', 'ancient', 'aged', 'elderly', 'vintage', 'archaic'}),
        frozenset({'new', 'modern', 'recent', 'contemporary', 'novel', 'fresh'}),
        frozenset({'good', 'excellent', 'great', 'fine', 'superior', 'outstanding'}),
        frozenset({'bad', 'poor', 'terrible', 'awful', 'dreadful', 'inferior'}),
        frozenset({'theory', 'hypothesis', 'concept', 'idea', 'notion', 'framework'}),
        frozenset({'method', 'technique', 'approach', 'strategy', 'procedure', 'process'}),
        frozenset({'problem', 'issue', 'challenge', 'difficulty', 'obstacle', 'complication'}),
        frozenset({'solution', 'answer', 'resolution', 'remedy', 'fix'}),
        frozenset({'part', 'component', 'element', 'piece', 'section', 'segment', 'portion'}),
        frozenset({'whole', 'entire', 'complete', 'total', 'full'}),
        frozenset({'theme', 'motif', 'subject', 'topic', 'central idea'}),
        frozenset({'conflict', 'struggle', 'tension', 'clash', 'dispute', 'confrontation'}),
        frozenset({'symbol', 'representation', 'emblem', 'metaphor', 'sign'}),
        frozenset({'setting', 'backdrop', 'environment', 'context', 'locale'}),
        frozenset({'character', 'persona', 'figure', 'individual', 'role'}),
        frozenset({'plot', 'storyline', 'narrative', 'story arc'}),
        frozenset({'climax', 'peak', 'turning point', 'pinnacle', 'crescendo'}),
        frozenset({'conclusion', 'ending', 'resolution', 'denouement', 'finale'}),
    }

    def _fuzzy_in_set(word, word_set):
        if word in word_set:
            return True
        for w in word_set:
            d = _levenshtein(word, w)
            if d <= max(1, len(w) * 0.25):
                return True
        return False

    def _are_synonyms(w1, w2):
        w1s, w2s = _stem(w1), _stem(w2)
        for group in _SYNONYMS:
            stems = {_stem(w) for w in group}
            all_forms = group | stems
            if _fuzzy_in_set(w1s, all_forms) and _fuzzy_in_set(w2s, all_forms):
                return True
            if _fuzzy_in_set(w1, all_forms) and _fuzzy_in_set(w2, all_forms):
                return True
        return False

    ua_words = ua_c.split()
    ca_words = ca_c.split()

    if len(ua_words) == 1 and len(ca_words) == 1:
        if _are_synonyms(ua_words[0], ca_words[0]):
            return True

    if len(ua_words) >= 1 and len(ca_words) >= 1:
        content_stop = {'the', 'a', 'an', 'is', 'are', 'was', 'were', 'of', 'in', 'on', 'at', 'to', 'for', 'and', 'or', 'but', 'with', 'by', 'from', 'as', 'its', 'it'}
        ua_content = [w for w in ua_words if w not in content_stop]
        ca_content = [w for w in ca_words if w not in content_stop]

        if ua_content and ca_content and len(ua_content) == len(ca_content):
            all_match = all(
                w1 == w2 or _stem(w1) == _stem(w2) or _are_synonyms(w1, w2)
                for w1, w2 in zip(sorted(ua_content), sorted(ca_content))
            )
            if all_match:
                return True

        if ua_content and ca_content:
            matched = 0
            for uw in ua_content:
                for cw in ca_content:
                    if uw == cw or _stem(uw) == _stem(cw) or _are_synonyms(uw, cw):
                        matched += 1
                        break
            if matched >= len(ua_content) * 0.8 and matched >= len(ca_content) * 0.6:
                return True

    return False


def _detect_weak_topics(user_id, db: Session) -> List[str]:
    sessions = db.query(StudySession).filter(StudySession.user_id == user_id).all()
    quizzes = db.query(Quiz).filter(Quiz.user_id == user_id).all()
    flashcards = db.query(Flashcard).filter(Flashcard.user_id == user_id).all()

    topic_scores = {}

    for s in sessions:
        if s.topics_covered:
            for t in s.topics_covered:
                t = t.strip()
                if t:
                    if t not in topic_scores:
                        topic_scores[t] = {"quiz": [], "focus": [], "cards": 0, "card_total": 0}
                    if s.focus_score and s.focus_score > 0:
                        topic_scores[t]["focus"].append(s.focus_score)

    for q in quizzes:
        if q.weak_topics:
            for t in q.weak_topics:
                t = t.strip()
                if t:
                    if t not in topic_scores:
                        topic_scores[t] = {"quiz": [], "focus": [], "cards": 0, "card_total": 0}
                    topic_scores[t]["quiz"].append(30)

        if q.topics_tested:
            pct = float(q.score_achieved / q.max_score * 100) if q.max_score and q.max_score > 0 else 50
            for t in q.topics_tested:
                t = t.strip()
                if t:
                    if t not in topic_scores:
                        topic_scores[t] = {"quiz": [], "focus": [], "cards": 0, "card_total": 0}
                    topic_scores[t]["quiz"].append(pct)

    weak = []
    for topic, data in topic_scores.items():
        quiz_avg = sum(data["quiz"]) / len(data["quiz"]) if data["quiz"] else 50
        focus_avg = sum(data["focus"]) / len(data["focus"]) if data["focus"] else 50
        proficiency = (quiz_avg * 0.6) + (focus_avg * 0.4)
        if proficiency < 75:
            weak.append((topic, proficiency))

    weak.sort(key=lambda x: x[1])
    return [t[0] for t in weak[:15]]


def _calculate_next_due(frequency: str, day_of_week: int) -> datetime:
    now = datetime.now(timezone.utc)
    days_ahead = day_of_week - now.weekday()
    if days_ahead <= 0:
        if frequency == "weekly":
            days_ahead += 7
        elif frequency == "biweekly":
            days_ahead += 14
        elif frequency == "monthly":
            days_ahead += 30
        else:
            days_ahead += 7
    next_date = now + timedelta(days=days_ahead)
    return next_date.replace(hour=9, minute=0, second=0, microsecond=0)


def _quiz_response_dict(q: GeneratedQuiz) -> dict:
    return {
        "id": str(q.id),
        "user_id": str(q.user_id),
        "subject_id": str(q.subject_id) if q.subject_id else None,
        "title": q.title,
        "quiz_type": q.quiz_type,
        "source": q.source,
        "topic_focus": q.topic_focus or [],
        "total_questions": q.total_questions,
        "time_limit_minutes": q.time_limit_minutes,
        "status": q.status,
        "score_achieved": str(q.score_achieved) if q.score_achieved else None,
        "max_score": str(q.max_score) if q.max_score else None,
        "correct_count": q.correct_count or 0,
        "xp_earned": q.xp_earned or 0,
        "started_at": q.started_at.isoformat() if q.started_at else None,
        "completed_at": q.completed_at.isoformat() if q.completed_at else None,
        "created_at": q.created_at.isoformat() if q.created_at else None,
    }


def _quiz_detail_dict(q: GeneratedQuiz) -> dict:
    d = _quiz_response_dict(q)
    d["questions"] = [
        {
            "id": str(qq.id),
            "question_type": qq.question_type,
            "question_text": qq.question_text,
            "options": qq.options or [],
            "correct_answer": qq.correct_answer,
            "explanation": qq.explanation,
            "topic": qq.topic,
            "difficulty": qq.difficulty,
            "user_answer": qq.user_answer,
            "is_correct": qq.is_correct,
            "order_index": qq.order_index,
        }
        for qq in (q.questions or [])
    ]
    return d


def _schedule_dict(s: QuizSchedule) -> dict:
    return {
        "id": str(s.id),
        "frequency": s.frequency,
        "day_of_week": s.day_of_week,
        "question_count": s.question_count,
        "question_types": s.question_types or [],
        "enabled": s.enabled,
        "last_generated_at": s.last_generated_at.isoformat() if s.last_generated_at else None,
        "next_due_at": s.next_due_at.isoformat() if s.next_due_at else None,
        "created_at": s.created_at.isoformat() if s.created_at else None,
    }
