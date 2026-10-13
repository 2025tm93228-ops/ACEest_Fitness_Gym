"""Shared Pytest fixtures: each test gets a throwaway SQLite database."""
import os
import sys
import tempfile

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app import create_app  # noqa: E402


@pytest.fixture
def app():
    fd, path = tempfile.mkstemp(suffix=".db")
    os.close(fd)
    application = create_app(database=path)
    application.config["TESTING"] = True
    yield application
    os.unlink(path)


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def logged_workout(client):
    """Insert one known workout and return its JSON payload."""
    response = client.post(
        "/api/workouts",
        json={"client": "Ravi", "workout_type": "Strength", "duration_min": 45, "notes": "5x5"},
    )
    return response.get_json()["workout"]
