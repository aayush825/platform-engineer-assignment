"""WSGI entry point for Gunicorn.

Usage:
    gunicorn --config gunicorn.conf.py wsgi:app
"""

from app import create_app

app = create_app()

if __name__ == "__main__":
    # Local development convenience only. Production uses Gunicorn + systemd.
    app.run(host=app.config["APP_HOST"], port=app.config["APP_PORT"])
