# Platform Engineer Assignment — Written Solution

This document mirrors the six assignment parts. Each section states the chosen
design, why, commands/config, failure handling, security, and validation.

Stack: Python + Flask, Gunicorn, Nginx, systemd, PostgreSQL (RDS in AWS, Docker
locally), GitHub Actions CI/CD, AWS SSM for deployment, CloudWatch for
observability.

---

## 1. Deployment Approach (EC2)

**Design.** Immutable releases under `/opt/platform-app/releases/<id>` with a
`current` symlink. Nginx (public reverse proxy) → Gunicorn (localhost:8000) →
Flask. systemd owns the process lifecycle. Config comes from
`/etc/platform-app/platform-app.env` (0640, root:platform).

**Why.** Immutable releases make rollback a symlink switch instead of a risky
in-place `git reset`. Gunicorn on loopback keeps the app off the public
interface. systemd gives restart-on-failure and hardening.

**Server setup & packages.** `deployment/scripts/bootstrap_ec2.sh` installs
Python, Nginx, Git, PostgreSQL client (dnf for Amazon Linux 2023, apt for
Ubuntu — kept separate), creates the `platform` service user and directory
layout, installs the systemd unit and Nginx config, and drops the env-file
example.

**Directory structure.**
```text
/opt/platform-app/
├── current -> releases/<id>
├── releases/<id>/ (code + .venv)
└── shared/ (logs, last-known-good metadata)
```

**Dependencies.** Per-release virtualenv; `pip install -r requirements.txt`
(pinned). Never global installs. Tests run before the symlink switch.

**Application server.** `gunicorn.conf.py` binds `127.0.0.1:8000`, explicit
timeouts, stdout/stderr logging, `capture_output=True`, worker recycling.

**Nginx.** `deployment/nginx/platform-app.conf` proxies to the upstream, sets
`X-Forwarded-*`, HTTP→HTTPS redirect, exposes `/health` and `/ready`, denies
dotfiles. Validate with `sudo nginx -t && sudo systemctl reload nginx`.

**SSL.** Let's Encrypt/Certbot for a standalone EC2 with a real domain; TLS
termination at the ALB in the full architecture. Placeholders only
(`app.example.com`); no fabricated certs.

**Startup/restart.** `systemctl enable --now platform-app`;
`systemctl restart platform-app`; `ExecReload` sends HUP.

**Logs.** `journalctl -u platform-app`; Nginx logs in `/var/log/nginx/`; ship to
CloudWatch in AWS.

**Rollback.** See `deployment/scripts/deploy.sh` and `rollback.sh`: build new
release, test, start, health-gate, switch symlink only on success, roll back to
the previous release on failure. Database migrations use backward-compatible
expand/contract; no destructive auto-rollback.

**Validation.** `pytest -q`, `python -m compileall app`,
`systemd-analyze verify`, `nginx -t`, `bash -n deployment/scripts/*.sh`,
`curl -fsS http://127.0.0.1:8000/health`.

---

## 2. CI/CD Pipeline

**Design.** GitHub Actions (`.github/workflows/deploy.yml`). `test` job: lint +
pytest + pip-audit. `deploy` job (needs test, `environment: production` for
approvals): OIDC → assume AWS role → SSM Run Command invokes `deploy.sh` on the
tagged instance → poll command status → fail the job if the deploy fails.

**Why.** Free for the assignment, first-party AWS/GitHub actions, OIDC avoids
static keys, SSM avoids public SSH.

**Failure strategy.** Job goes red on test/lint/deploy/health failure. On-host
`deploy.sh` auto-rolls-back to the previous release when health checks fail; the
job still exits non-zero so a successful rollback never shows green.

**Security.** `id-token: write` for OIDC; role scoped to SSM on the target;
secrets never placed in SSM command strings.

---

## 3. Production Incident Investigation (502)

See `docs/incident-502-runbook.md`. Ordered flow: confirm symptom → Nginx →
app service → process/port → config → permissions → resources → root-cause table
(12 causes) → safe restoration. Principle: separate Nginx, upstream process,
port, application, dependency, and network failures before acting.

---

## 4. Security Review

See `docs/security-review.md` — 12 risks in a Risk/Evidence/Fix/Validation
matrix: committed secrets, over-permissive IAM, public RDS, open SGs, weak TLS,
debug mode, outdated deps, weak Linux perms/root process, missing backups,
missing monitoring, unsafe deploy access, weak auditability.

---

## 5. Small Code Change (Health Check)

`GET /health` (liveness, never touches the DB) returns
`{"status":"ok","service":"platform-app"}` with 200. `GET /ready` (readiness)
runs a bounded `SELECT 1`; returns 200 when the DB answers, 503
(`{"status":"unavailable","dependency":"database"}`) otherwise, never leaking
credentials or exception detail. Code: `app/routes.py`, `app/db.py`. Tests:
`tests/test_health.py` (200/JSON, ready-healthy 200, ready-unhealthy 503,
content-type, no-auth).

---

## 6. AWS Architecture

See `docs/aws-architecture.md` and `architecture/`. Route 53 → ALB (HTTPS) →
private EC2 (Nginx→Gunicorn→Flask) → private RDS PostgreSQL; S3 for
assets/backups; IAM instance role; least-privilege SGs; CloudWatch metrics/logs
and alarms; CloudTrail for audit; GitHub Actions → OIDC → SSM → EC2 for deploys.
