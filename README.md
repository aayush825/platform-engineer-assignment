# Platform Engineer Assignment — platform-app

A small, production-shaped Flask service with a full deployment story: EC2 +
Nginx + Gunicorn + systemd, GitHub Actions CI/CD via OIDC + SSM, a 502 incident
runbook, a security review, health-check endpoints, and an AWS architecture.

> All hostnames, ARNs, and credentials in this repo are placeholders. Replace
> them in a real environment. No secrets belong in Git.

## 1. Overview
Liveness (`/health`) and readiness (`/ready`) endpoints backed by Flask, served
by Gunicorn on loopback behind Nginx, managed by systemd, deployed as immutable
releases with symlink-based rollback.

## 2. Assignment mapping
| Part | Deliverable |
|------|-------------|
| 1 Deployment | `deployment/`, `docs/solution.md` §1 |
| 2 CI/CD | `.github/workflows/deploy.yml`, `docs/solution.md` §2 |
| 3 502 Incident | `docs/incident-502-runbook.md` |
| 4 Security | `docs/security-review.md` |
| 5 Code change | `app/routes.py`, `app/db.py`, `tests/test_health.py` |
| 6 AWS architecture | `docs/aws-architecture.md`, `architecture/` |

## 3. Local setup
```bash
python -m venv .venv
# Windows PowerShell: .venv\Scripts\Activate.ps1
# Linux/macOS:        source .venv/bin/activate
pip install -r requirements-dev.txt
```

## 4. Test commands
```bash
pytest -q
python -m compileall app
ruff check .
```

## 5. Health endpoint examples
```bash
curl -i http://127.0.0.1:8000/health   # 200 {"status":"ok","service":"platform-app"}
curl -i http://127.0.0.1:8000/ready    # 200 when DB reachable, 503 otherwise
```
Run locally: `python wsgi.py` (or `docker compose up -d` for app + PostgreSQL).

## 6. Deployment architecture
Nginx (public reverse proxy) → Gunicorn (127.0.0.1:8000) → Flask. systemd owns
the lifecycle. Immutable releases under `/opt/platform-app/releases/<id>` with a
`current` symlink; rollback is a symlink switch.

## 7. EC2 deployment steps
```bash
sudo bash deployment/scripts/bootstrap_ec2.sh        # one-time server setup
# edit /etc/platform-app/platform-app.env with real values (not committed)
sudo bash deployment/scripts/deploy.sh <release_id> <commit_sha> <repo_url>
sudo bash deployment/scripts/rollback.sh <previous_release>   # if needed
```

## 8. CI/CD flow
Push to `main` → test job (ruff + pytest + pip-audit) → deploy job (OIDC →
assume AWS role → SSM Run Command runs `deploy.sh` on the tagged instance) →
health gate. Failures roll back on-host and keep the job red.

## 9. 502 troubleshooting quick reference
Confirm symptom → Nginx → app service → process/port → config → permissions →
resources. Full runbook: `docs/incident-502-runbook.md`.

## 10. Security controls
Non-root service user, hardened systemd unit, no committed secrets, OIDC (no
static keys), SSM instead of public SSH, private RDS, least-privilege SGs. Full
matrix: `docs/security-review.md`.

## 11. AWS architecture
Route 53 → ALB (HTTPS) → private EC2 → private RDS; S3, IAM, CloudWatch,
CloudTrail. See `docs/aws-architecture.md` and `architecture/architecture.mmd`.

## 12. Cost-conscious / free-tool notes
GitHub Actions, draw.io, Mermaid, Let's Encrypt, Docker Compose, pytest, Ruff,
pip-audit. AWS resources may incur charges — verify current pricing/free-tier
before provisioning. The repo is complete without live infrastructure.

## 13. Security warning
Every placeholder (domains, ARNs, connection strings) must be replaced in a real
environment. Never commit `.env` files or credentials.
