"""Gunicorn entry point."""

from app.web import create_app

app = create_app()
