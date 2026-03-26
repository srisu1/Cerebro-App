from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    APP_NAME: str = "CEREBRO"
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "cerebro-dev-secret-key-change-in-production-2026"

    DATABASE_URL: str = "postgresql://cerebro_admin:cerebro_dev_2026@localhost:5432/cerebro_db"
    DATABASE_TEST_URL: str = "postgresql://cerebro_admin:cerebro_dev_2026@localhost:5432/cerebro_test_db"

    REDIS_URL: str = "redis://localhost:6379/0"

    JWT_SECRET_KEY: str = "cerebro-jwt-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    GOOGLE_CLIENT_ID: str = ""  # set via .env or environment variable

    BACKEND_HOST: str = "0.0.0.0"
    BACKEND_PORT: int = 8000
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:8000",
    ]

    class Config:
        env_file = "../.env"
        env_file_encoding = "utf-8"
        case_sensitive = True
        extra = "ignore"


settings = Settings()
