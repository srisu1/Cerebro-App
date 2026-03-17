try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.routers import auth, study, health, analytics, quiz_engine, calendar, daily, gamification, insights

import app.models.quiz_engine  # noqa: F401
import app.models.calendar     # noqa: F401

Base.metadata.create_all(bind=engine)

# auto-migration: add deck_id to flashcards if missing
from sqlalchemy import text as _sql_text, inspect as _sql_inspect
with engine.connect() as _conn:
    _inspector = _sql_inspect(engine)
    _cols = [c["name"] for c in _inspector.get_columns("flashcards")]
    if "deck_id" not in _cols:
        print("[STARTUP] Adding deck_id column to flashcards table...")
        _conn.execute(_sql_text(
            "ALTER TABLE flashcards ADD COLUMN deck_id UUID "
            "REFERENCES flashcard_decks(id) ON DELETE CASCADE"
        ))
        _conn.execute(_sql_text(
            "CREATE INDEX IF NOT EXISTS ix_flashcards_deck_id ON flashcards(deck_id)"
        ))
        _conn.commit()
        print("[STARTUP] deck_id column added successfully.")

# seed mood definitions if empty
from app.database import SessionLocal
from app.models.health import MoodDefinition


def _seed_mood_definitions():
    db = SessionLocal()
    try:
        if db.query(MoodDefinition).count() == 0:
            print("[STARTUP] Seeding mood definitions...")
            moods = [
                {"name": "Happy", "display_order": 1, "color": "#FFD93D",
                 "eyes_asset_path": "assets/avatar/expressions/happy/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/happy/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/happy/nose.png"},
                {"name": "Sad", "display_order": 2, "color": "#6C9BCF",
                 "eyes_asset_path": "assets/avatar/expressions/sad/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/sad/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/sad/nose.png"},
                {"name": "Anxious", "display_order": 3, "color": "#E8A87C",
                 "eyes_asset_path": "assets/avatar/expressions/anxious/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/anxious/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/anxious/nose.png"},
                {"name": "Calm", "display_order": 4, "color": "#95E1D3",
                 "eyes_asset_path": "assets/avatar/expressions/calm/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/calm/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/calm/nose.png"},
                {"name": "Excited", "display_order": 5, "color": "#FF6B6B",
                 "eyes_asset_path": "assets/avatar/expressions/excited/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/excited/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/excited/nose.png"},
                {"name": "Tired", "display_order": 6, "color": "#C9B1FF",
                 "eyes_asset_path": "assets/avatar/expressions/tired/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/tired/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/tired/nose.png"},
                {"name": "Angry", "display_order": 7, "color": "#FF8C94",
                 "eyes_asset_path": "assets/avatar/expressions/angry/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/angry/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/angry/nose.png"},
                {"name": "Focused", "display_order": 8, "color": "#88D8B0",
                 "eyes_asset_path": "assets/avatar/expressions/grateful/eyes.png",
                 "mouth_asset_path": "assets/avatar/expressions/grateful/mouth.png",
                 "nose_asset_path": "assets/avatar/expressions/grateful/nose.png"},
            ]
            for m in moods:
                db.add(MoodDefinition(**m))
            db.commit()
            print(f"[STARTUP] Seeded {len(moods)} mood definitions.")
        else:
            renames = {"Energetic": "Excited", "Stressed": "Angry"}
            for old_name, new_name in renames.items():
                row = db.query(MoodDefinition).filter(MoodDefinition.name == old_name).first()
                if row:
                    row.name = new_name
                    print(f"[STARTUP] Renamed mood '{old_name}' -> '{new_name}'")
            db.commit()
    except Exception as e:
        print(f"[STARTUP] Mood seed error: {e}")
        db.rollback()
    finally:
        db.close()


_seed_mood_definitions()

# seed achievements if empty
from app.models.gamification import Achievement


def _seed_achievements():
    db = SessionLocal()
    try:
        if db.query(Achievement).count() == 0:
            print("[STARTUP] Seeding achievements...")
            achievements = [
                # study
                {"name": "First Steps", "description": "Complete your first study session",
                 "category": "study", "icon": "school", "xp_reward": 25, "coin_reward": 5,
                 "condition_type": "count", "condition_value": 1,
                 "condition_field": "study_sessions.count", "rarity": "common"},
                {"name": "Bookworm", "description": "Complete 10 study sessions",
                 "category": "study", "icon": "menu_book", "xp_reward": 100, "coin_reward": 20,
                 "condition_type": "count", "condition_value": 10,
                 "condition_field": "study_sessions.count", "rarity": "common"},
                {"name": "Study Marathon", "description": "Study for 120 minutes in a single session",
                 "category": "study", "icon": "timer", "xp_reward": 200, "coin_reward": 50,
                 "condition_type": "score", "condition_value": 120,
                 "condition_field": "study_sessions.duration", "rarity": "rare"},
                {"name": "Scholar", "description": "Complete 50 study sessions",
                 "category": "study", "icon": "workspace_premium", "xp_reward": 300, "coin_reward": 75,
                 "condition_type": "count", "condition_value": 50,
                 "condition_field": "study_sessions.count", "rarity": "epic"},
                {"name": "Perfect Score", "description": "Score 100% on a quiz",
                 "category": "study", "icon": "star", "xp_reward": 150, "coin_reward": 30,
                 "condition_type": "score", "condition_value": 100,
                 "condition_field": "quizzes.percentage", "rarity": "rare"},
                {"name": "Flash Master", "description": "Review 100 flashcards",
                 "category": "study", "icon": "flash_on", "xp_reward": 200, "coin_reward": 40,
                 "condition_type": "count", "condition_value": 100,
                 "condition_field": "flashcards.reviews", "rarity": "rare"},
                # health
                {"name": "Sleep Champion", "description": "Get 7+ hours of sleep for 7 consecutive nights",
                 "category": "health", "icon": "bedtime", "xp_reward": 150, "coin_reward": 30,
                 "condition_type": "streak", "condition_value": 7,
                 "condition_field": "sleep_logs.streak", "rarity": "rare"},
                {"name": "Mood Tracker", "description": "Log your mood for 7 days in a row",
                 "category": "health", "icon": "mood", "xp_reward": 100, "coin_reward": 20,
                 "condition_type": "streak", "condition_value": 7,
                 "condition_field": "mood_entries.streak", "rarity": "common"},
                {"name": "Wellness Warrior", "description": "Log your mood for 30 days in a row",
                 "category": "health", "icon": "favorite", "xp_reward": 400, "coin_reward": 100,
                 "condition_type": "streak", "condition_value": 30,
                 "condition_field": "mood_entries.streak", "rarity": "legendary"},
                {"name": "Med Adherent", "description": "Take all medications for 7 days straight",
                 "category": "health", "icon": "medication", "xp_reward": 150, "coin_reward": 30,
                 "condition_type": "streak", "condition_value": 7,
                 "condition_field": "medications.adherence", "rarity": "rare"},
                # daily
                {"name": "Habit Former", "description": "Maintain a 7-day habit streak",
                 "category": "daily", "icon": "repeat", "xp_reward": 150, "coin_reward": 30,
                 "condition_type": "streak", "condition_value": 7,
                 "condition_field": "habits.streak", "rarity": "common"},
                {"name": "Habit Master", "description": "Maintain a 21-day habit streak",
                 "category": "daily", "icon": "emoji_events", "xp_reward": 300, "coin_reward": 75,
                 "condition_type": "streak", "condition_value": 21,
                 "condition_field": "habits.streak", "rarity": "epic"},
                {"name": "Consistent Student", "description": "Log in for 30 days in a row",
                 "category": "daily", "icon": "calendar_month", "xp_reward": 500, "coin_reward": 100,
                 "condition_type": "streak", "condition_value": 30,
                 "condition_field": "user.login_streak", "rarity": "legendary"},
                {"name": "Early Bird", "description": "Complete a study session before 9 AM",
                 "category": "daily", "icon": "wb_sunny", "xp_reward": 75, "coin_reward": 15,
                 "condition_type": "milestone", "condition_value": 1,
                 "condition_field": "study_sessions.count", "rarity": "common"},
            ]
            for a in achievements:
                db.add(Achievement(**a))
            db.commit()
            print(f"[STARTUP] Seeded {len(achievements)} achievements.")
    except Exception as e:
        print(f"[STARTUP] Achievement seed error: {e}")
        db.rollback()
    finally:
        db.close()


_seed_achievements()

app = FastAPI(
    title="CEREBRO API",
    description="Student Companion Backend",
    version="0.3.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"app": settings.APP_NAME, "status": "running", "version": "0.3.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy", "database": "connected", "environment": settings.APP_ENV}


app.include_router(auth.router, prefix="/api/v1")
app.include_router(study.router, prefix="/api/v1")
app.include_router(health.router, prefix="/api/v1")
app.include_router(analytics.router, prefix="/api/v1")
app.include_router(quiz_engine.router, prefix="/api/v1")
app.include_router(calendar.router, prefix="/api/v1")
app.include_router(daily.router, prefix="/api/v1")
app.include_router(gamification.router, prefix="/api/v1")
app.include_router(insights.router, prefix="/api/v1")
