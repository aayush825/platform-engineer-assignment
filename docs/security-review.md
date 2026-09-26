# Security Review

The assignment asks for at least five risks; this review documents twelve, each
with why it matters, a concrete fix, and how to validate the fix.

| # | Risk | Evidence / Why it matters | Fix | Validation |
|---|------|---------------------------|-----|------------|
| 1 | Secrets committed to source | Leaked credentials in Git history are permanent and scanned by attackers | Remove from Git; rotate exposed creds; inject via env/Secrets Manager/SSM; add secret scanning + pre-commit | Repo search + CI secret scan (Gitleaks); confirm no creds in logs |
| 2 | Over-permissive IAM | Broad permissions turn one compromise into account-wide blast radius | Least privilege: instance role minimal; deploy role scoped to target; OIDC trust limited to repo/branch; no long-lived keys | Inspect policy actions/resources; show denied access for unrelated actions |
| 3 | Publicly exposed RDS | A public database is directly attackable from the internet | Private subnets; `PubliclyAccessible=false`; inbound 5432 only from app SG; encryption at rest + TLS | Confirm not publicly reachable; SG references app SG only |
| 4 | Overly open security groups | `0.0.0.0/0` on SSH/DB is a standing invitation | Internet→ALB:443 only; ALB→EC2 on app port; EC2→RDS:5432; manage via SSM not public SSH | Review inbound/outbound rules; no `0.0.0.0/0` on 22/5432 |
| 5 | Missing/weak TLS | Plaintext traffic can be sniffed or tampered | HTTPS; HTTP→HTTPS redirect; TLS 1.2/1.3; auto cert renewal | `curl -I http://...` redirects; valid HTTPS cert |
| 6 | Debug mode enabled | Stack traces leak internals and code paths | `APP_ENV=production`, `DEBUG=false`; generic error pages; details only in private logs | Trigger a controlled error in test; verify no stack trace returned |
| 7 | Outdated dependencies | Known CVEs in old packages | Pin deps; update regularly; `pip-audit`; test after updates | CI dependency scan; dependency review |
| 8 | Weak Linux perms / root process | Root process = full host compromise on RCE | Dedicated non-root service user; 750/640 perms; env file root:platform 0640; systemd hardening | Inspect ownership + `systemd-analyze verify` |
| 9 | Missing backups | No recovery path after data loss/corruption | RDS automated backups; defined retention; snapshots; test restores | Show backup settings + restore test plan |
| 10 | Missing monitoring/alerts | Outages go unnoticed until users report them | CloudWatch metrics/logs; alarms on ALB 5xx, target health, EC2 status, RDS CPU/storage/connections | Alarm test procedure documented |
| 11 | Unsafe deployment access | Static keys / open SSH widen attack surface | SSM over SSH; OIDC over static keys; least-privilege deploy role; protected main; env approvals | Inspect GitHub env/branch protection + IAM trust |
| 12 | Weak auditability | Cannot answer "who changed what, when" | CloudTrail; GitHub deployment history; journald; centralized CloudWatch logs; commit SHA per release | Trace commit → pipeline → release → service logs |

## Notes on implementation in this repo

- `.gitignore` excludes `.env`/`*.env` and allows only `*.env.example`.
- `app/config.py` reads all config from the environment; no hard-coded secrets.
- `app/db.py` never returns credentials or raw exceptions to callers.
- systemd unit runs as `platform` (non-root) with `NoNewPrivileges`, `PrivateTmp`,
  `ProtectSystem=full`, and related hardening.
- CI uses OIDC (`id-token: write`) and SSM Run Command; no static AWS keys.
- Nginx denies access to dotfiles and forwards `X-Forwarded-*` headers.
