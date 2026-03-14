# CEREBRO

A student companion app built with **Flutter** (frontend) and **FastAPI** (backend). Designed to help students manage academics, health, habits, and daily life — all in one place.

## Features

- **Study Management** — Subjects, study sessions with Pomodoro timer, flashcards with SM-2 spaced repetition, AI-powered quiz generation
- **Health Tracking** — Mood logging, sleep tracking, medication reminders, wellness analytics
- **Calendar** — Study event scheduling with Google Calendar two-way sync, AI smart schedule generation based on knowledge gaps
- **Analytics** — Knowledge map, gap detection, exam readiness predictions, weekly focus trends
- **Gamification** — XP system, achievements, avatar customization, dual currency (XP + Cash)
- **Daily Life** — Habit tracking with streaks, password manager, class schedule

## Tech Stack

### Frontend (`cerebro_app/`)
- Flutter 3.x with Dart
- Riverpod for state management
- GoRouter for navigation
- SharedPreferences for local caching
- Google Fonts + custom Toca Boca-inspired aesthetic

### Backend (`cerebro_backend/`)
- FastAPI (Python 3.12)
- SQLAlchemy ORM + PostgreSQL
- Alembic for database migrations
- JWT authentication with bcrypt + Google OAuth2
- Multi-provider AI integration (Groq, Anthropic, OpenAI, Google) for quiz generation

## Getting Started

### Backend

```bash
cd cerebro_backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # configure your database and API keys
alembic upgrade head
uvicorn app.main:app --reload --port 8000
```

### Frontend

```bash
cd cerebro_app
flutter pub get
flutter run
```

### Environment Variables

The backend requires a `.env` file with:
- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET` — Secret key for JWT tokens
- `GOOGLE_CLIENT_ID` — For Google OAuth
- `GOOGLE_CLIENT_SECRET` — For Google Calendar sync
- AI provider keys (at least one): `GROQ_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_AI_KEY`

## Project Structure

```
cerebro_backend/
├── app/
│   ├── config.py          # settings from env
│   ├── database.py        # SQLAlchemy engine + session
│   ├── main.py            # FastAPI app entry point
│   ├── models/            # SQLAlchemy ORM models
│   ├── routers/           # API route handlers
│   ├── schemas/           # Pydantic request/response schemas
│   ├── services/          # Business logic (quiz generation, etc.)
│   └── utils/             # Auth helpers, shared utilities
├── alembic/               # Database migrations
├── sql/                   # Seed data
└── tests/

cerebro_app/
├── lib/
│   ├── config/            # Theme, constants, router
│   ├── models/            # Data models
│   ├── providers/         # Riverpod state providers
│   ├── screens/           # UI screens by feature
│   └── services/          # API service layer
├── assets/                # Audio, avatars, store images
└── test/
```

## License

Private project — not open source.
