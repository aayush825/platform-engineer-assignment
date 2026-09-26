"""Tests for the /health and /ready endpoints."""

from __future__ import annotations

import pytest

from app import create_app
from app.config import Config


@pytest.fixture
def client():
    app = create_app(Config(APP_ENV="testing", DATABASE_URL=None))
    app.testing = True
    with app.test_client() as c:
        yield c


def test_health_returns_200_and_json(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.is_json
    body = resp.get_json()
    assert body["status"] == "ok"
    assert body["service"] == "platform-app"


def test_health_content_type_is_json(client):
    resp = client.get("/health")
    assert resp.headers["Content-Type"].startswith("application/json")


def test_ready_returns_200_when_db_healthy(client, monkeypatch):
    # Mock the DB dependency as healthy.
    monkeypatch.setattr("app.routes.check_database", lambda url, timeout: True)
    resp = client.get("/ready")
    assert resp.status_code == 200
    assert resp.is_json
    body = resp.get_json()
    assert body["status"] == "ready"
    assert body["dependencies"]["database"] == "ok"


def test_ready_returns_503_when_db_unavailable(client, monkeypatch):
    # Mock the DB dependency as unavailable.
    monkeypatch.setattr("app.routes.check_database", lambda url, timeout: False)
    resp = client.get("/ready")
    assert resp.status_code == 503
    assert resp.is_json
    body = resp.get_json()
    assert body["status"] == "unavailable"
    assert body["dependency"] == "database"


def test_health_requires_no_authentication(client):
    # Health endpoints must be reachable without auth for the LB/monitoring path.
    resp = client.get("/health")
    assert resp.status_code == 200
