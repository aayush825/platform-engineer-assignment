"""Application factory for the platform-app Flask service."""

from __future__ import annotations

import logging

from flask import Flask

from .config import Config
from .routes import bp as health_bp


def create_app(config: Config | None = None) -> Flask:
    """Create and configure the Flask application.

    Args:
        config: Optional pre-built config. When omitted, configuration is
            loaded from environment variables.

    Returns:
        A configured Flask application instance.
    """
    app = Flask(__name__)
    app.config.from_object(config or Config.from_env())

    logging.basicConfig(
        level=app.config.get("LOG_LEVEL", "INFO"),
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )

    app.register_blueprint(health_bp)
    return app
