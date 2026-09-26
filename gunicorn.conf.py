"""Gunicorn configuration for platform-app.

Bind to localhost only; Nginx is the public-facing reverse proxy. Worker
counts are conservative here; tune them with load testing in real production.
"""

import multiprocessing
import os

# Bind to loopback only. Nginx proxies public traffic to this address.
bind = os.getenv("GUNICORN_BIND", "127.0.0.1:8000")

# Conservative default. For real production, load-test before increasing.
workers = int(os.getenv("GUNICORN_WORKERS", str(multiprocessing.cpu_count() * 2 + 1)))
worker_class = "sync"

# Explicit timeouts.
timeout = int(os.getenv("GUNICORN_TIMEOUT", "30"))
graceful_timeout = int(os.getenv("GUNICORN_GRACEFUL_TIMEOUT", "30"))
keepalive = int(os.getenv("GUNICORN_KEEPALIVE", "5"))

# Guard against oversized request lines/headers.
limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# Logging to stdout/stderr so journald/CloudWatch can capture it.
accesslog = "-"
errorlog = "-"
loglevel = os.getenv("LOG_LEVEL", "info").lower()
capture_output = True

# Recycle workers to bound memory growth.
max_requests = 1000
max_requests_jitter = 100
