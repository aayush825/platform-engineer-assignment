.PHONY: install test lint fmt audit compile run up down health verify

install:
	pip install -r requirements-dev.txt

test:
	pytest -q

lint:
	ruff check .

fmt:
	ruff format .

audit:
	pip-audit -r requirements.txt

compile:
	python -m compileall app wsgi.py

run:
	python wsgi.py

up:
	docker compose up -d

down:
	docker compose down

health:
	curl -fsS http://127.0.0.1:8000/health

verify: compile lint test
	@echo "verify complete"
