"""HTTP routes: liveness and readiness health checks.

- GET /health : liveness. The application process is alive. Never depends on
  the database, so a DB outage does not look like a process outage.
- GET /ready  : readiness. The application AND its database dependency are
  ready to serve traffic.
"""

from __future__ import annotations

from flask import Blueprint, current_app, jsonify

from .db import check_database

bp = Blueprint("health", __name__)


@bp.get("/health")
def health():
    """Liveness probe. Returns 200 as long as the process can serve requests."""
    payload = {
        "status": "ok",
        "service": current_app.config.get("SERVICE_NAME", "platform-app"),
    }
    return jsonify(payload), 200


@bp.get("/ready")
def ready():
    """Readiness probe. Returns 200 only when dependencies are reachable."""
    db_ok = check_database(
        current_app.config.get("DATABASE_URL"),
        current_app.config.get("DB_CONNECT_TIMEOUT", 2),
    )

    if db_ok:
        return (
            jsonify(
                {
                    "status": "ready",
                    "service": current_app.config.get("SERVICE_NAME", "platform-app"),
                    "dependencies": {"database": "ok"},
                }
            ),
            200,
        )

    # 503 signals to the load balancer/orchestrator not to route traffic yet.
    return (
        jsonify(
            {
                "status": "unavailable",
                "dependency": "database",
            }
        ),
        503,
    )
