# Local reproducibility image for platform-app.
FROM python:3.12-slim

# Run as a non-root user, matching the production posture.
RUN useradd --system --create-home --shell /usr/sbin/nologin appuser

WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["gunicorn", "--config", "gunicorn.conf.py", "wsgi:app"]
