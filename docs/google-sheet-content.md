# Google Sheet — Submission Content

Paste the table below into a Google Sheet, then publish it with a public share
link per the assignment instructions. Kiro does not publish the sheet
automatically; publishing is a manual step for the human operator.

## Summary table (tab-separated, ready to paste)

```text
Section	Implementation	Evidence/File	Validation
Deployment	EC2 + Nginx + Gunicorn + systemd, immutable releases + symlink	deployment/, docs/solution.md §1	curl /health, systemctl status, nginx -t, systemd-analyze verify
CI/CD	GitHub Actions: test gate + OIDC + SSM Run Command + rollback	.github/workflows/deploy.yml, docs/solution.md §2	pipeline run, health gate, job red on failure
502 Incident	Structured runbook, 12 root causes, safe restoration	docs/incident-502-runbook.md	local simulation / checklist
Security	12 risks with fixes + validation	docs/security-review.md	review matrix, gitleaks, pip-audit
Health Check	GET /health (liveness) + GET /ready (DB readiness)	app/routes.py, app/db.py, tests/test_health.py	pytest -q (5 tests), curl
AWS Architecture	Route53 + ALB + EC2 + RDS + IAM + SG + S3 + CloudWatch + CloudTrail	docs/aws-architecture.md, architecture/	diagram review
```

## How to publish
1. Create a new Google Sheet.
2. Paste the block above (Sheets splits on tabs into columns).
3. File → Share → Publish to web (or set link sharing to "Anyone with the link").
4. Copy the public URL into your submission.
