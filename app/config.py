"""Environment-driven configuration.

All configuration is read from environment variables only. No secrets are
hard-coded. See .env.example for the full list of supported variables.
"""

from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    """Immutable application configuration loaded from the environment."""

    APP_ENV: str = "production"
    APP_HOST: str = "127.0.0.1"
    APP_PORT: int = 8000
    SERVICE_NAME: str = "platform-app"
    DATABASE_URL: str | None = None
    LOG_LEVEL: str = "INFO"
    SECRET_KEY: str = "change-me-not-committed"
    # Bounded timeout (seconds) for the readiness DB probe.
    DB_CONNECT_TIMEOUT: int = 2
    # Flask debug MUST be false in production.
    DEBUG: bool = False

    @classmethod
    def from_env(cls) -> Config:
        """Build a Config from process environment variables."""
        return cls(
            APP_ENV=os.getenv("APP_ENV", "production"),
            APP_HOST=os.getenv("APP_HOST", "127.0.0.1"),
            APP_PORT=int(os.getenv("APP_PORT", "8000")),
            SERVICE_NAME=os.getenv("SERVICE_NAME", "platform-app"),
            DATABASE_URL=os.getenv("DATABASE_URL"),
            LOG_LEVEL=os.getenv("LOG_LEVEL", "INFO"),
            SECRET_KEY=os.getenv("SECRET_KEY", "change-me-not-committed"),
            DB_CONNECT_TIMEOUT=int(os.getenv("DB_CONNECT_TIMEOUT", "2")),
            DEBUG=os.getenv("APP_ENV", "production").lower() != "production"
            and os.getenv("FLASK_DEBUG", "0") == "1",
        )
