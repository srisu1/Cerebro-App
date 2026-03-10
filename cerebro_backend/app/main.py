"""
CEREBRO Backend
uvicorn app.main:app --reload --port 8000
"""

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.routers import auth, study, health, quiz_engine

# TODO: use alembic migrations instead of this
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="CEREBRO API",
    description="Student Companion Backend",
    version="0.1.0",
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
    return {"app": settings.APP_NAME, "status": "running", "version": "0.1.0"}


@app.get("/health")
def health_check():
    return {"status": "healthy", "database": "connected", "environment": settings.APP_ENV}


app.include_router(auth.router, prefix="/api/v1")
app.include_router(study.router, prefix="/api/v1")
app.include_router(health.router, prefix="/api/v1")
app.include_router(quiz_engine.router, prefix="/api/v1")
