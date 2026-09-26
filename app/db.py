"""Database readiness probe.

The probe opens a short, bounded connection and runs ``SELECT 1``. It never
returns credentials or raw exception details to callers; failures are logged
server-side and surfaced only as a boolean.
"""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


def check_database(database_url: str | None, connect_timeout: int = 2) -> bool:
    """Return True when the database answers a trivial query.

    Args:
        database_url: PostgreSQL connection URL, or None when no DB is
            configured.
        connect_timeout: Bounded connection timeout in seconds.

    Returns:
        True if the database responded to ``SELECT 1``; otherwise False.
    """
    if not database_url:
        # No database configured -> readiness is not gated on a DB.
        return True

    try:
        # Imported lazily so the liveness path never needs the driver.
        import psycopg  # type: ignore

        with psycopg.connect(database_url, connect_timeout=connect_timeout) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        return True
    except Exception:  # noqa: BLE001 - we deliberately catch and log all failures
        # Log the real exception server-side; never leak details to the caller.
        logger.exception("Database readiness check failed")
        return False
