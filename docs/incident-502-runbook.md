# 502 Bad Gateway — Production Incident Runbook

A 502 from Nginx means Nginx received an invalid (or no) response from its
upstream. Treat it as an Nginx-to-upstream failure until proven otherwise.
Collect evidence first, then make the smallest safe change. Do not restart
everything reflexively.

## Step 1 — Confirm the symptom

```bash
curl -I https://app.example.com
curl -vk https://app.example.com/health
```

Determine:
- Does Nginx itself respond (any HTTP status) or is it unreachable?
- Does `/health` return 502, 503, 404, or something else?
- Is it every endpoint or only some routes?

## Step 2 — Check Nginx

```bash
sudo systemctl status nginx --no-pager
sudo nginx -t
sudo tail -n 200 /var/log/nginx/error.log
sudo tail -n 200 /var/log/nginx/access.log
```

Look for: `connect() failed (111: Connection refused)`, `upstream timed out`,
`no live upstreams`, wrong upstream host/port, permission errors, TLS issues.

## Step 3 — Check the application service

```bash
sudo systemctl status platform-app --no-pager
sudo journalctl -u platform-app -n 300 --no-pager
sudo journalctl -u platform-app --since "15 min ago" --no-pager
```

Look for: process crash, missing Python module, invalid env var, DB connection
failure, port conflict, permission failure, migration failure, OOM kill.

## Step 4 — Check process and port

```bash
sudo ss -lntp | grep ':8000'
sudo lsof -nP -iTCP:8000 -sTCP:LISTEN
ps aux | grep '[g]unicorn'
curl -v http://127.0.0.1:8000/health
```

Interpretation:
- Nothing on 8000 → app is down or bound elsewhere.
- Listener exists but localhost health fails → application problem.
- Localhost works but Nginx returns 502 → Nginx upstream/routing/permission.
- Nginx works but ALB errors → check target group health, listener, SG, path.

## Step 5 — Check configuration

```bash
sudo systemctl cat platform-app
sudo systemctl cat nginx
sudo ls -la /etc/platform-app/
# Inspect env keys WITHOUT printing secret values into tickets:
sudo sed -n '1,200p' /etc/platform-app/platform-app.env
```

Redact secret values. Never paste them into incident notes.

## Step 6 — Check permissions

```bash
namei -l /opt/platform-app/current/wsgi.py
sudo -u platform test -r /opt/platform-app/current/wsgi.py && echo readable
sudo -u platform test -x /opt/platform-app/current/.venv/bin/gunicorn && echo executable
```

Common trap: the service user cannot traverse a parent directory even though
the final file looks readable.

## Step 7 — Check resources

```bash
df -h
df -i
free -m
uptime
top -b -n1 | head -40
sudo dmesg -T | tail -100
```

Consider disk full, inode exhaustion, memory pressure/OOM, CPU saturation,
process exhaustion.

## Common root causes

| # | Root cause | Typical signal |
|---|------------|----------------|
| 1 | Gunicorn stopped/crashed | `systemctl status` inactive/failed; journal traceback |
| 2 | Gunicorn bound to wrong port/socket | nothing on `:8000`; bound elsewhere |
| 3 | Nginx upstream points to wrong port/socket | `connect() failed` in error.log |
| 4 | Bad deploy / missing dependency | ImportError in journal |
| 5 | Env vars missing/malformed | startup error, KeyError |
| 6 | File ownership/permissions changed | permission denied; `namei` shows gap |
| 7 | App hangs/times out | `upstream timed out` |
| 8 | Database outage → readiness fails | `/ready` 503; DB errors in journal |
| 9 | EC2 resource exhaustion | OOM in dmesg; disk/inode full |
| 10 | Nginx config syntax/reload issue | `nginx -t` fails |
| 11 | SG/network path issue (ALB→EC2) | ALB target unhealthy; no packets to EC2 |
| 12 | Wrong health-check path | target unhealthy though app is up |

## Safe restoration procedure

1. Capture current Nginx/application logs.
2. Confirm whether the current release changed just before the incident.
3. Run the local health check (`deployment/scripts/health_check.sh`).
4. If a new release is faulty and the previous release is known-good, roll back
   with `deployment/scripts/rollback.sh <previous-release>`.
5. Restart/reload only the affected service.
6. Validate localhost → Nginx → external endpoint in that order.
7. Watch error rates/logs for several minutes before declaring recovery.
8. Record cause, fix, and prevention.

Do not purge logs, drop databases, or repeatedly reboot the host as a first
response.
