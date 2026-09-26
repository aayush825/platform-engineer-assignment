# AWS Architecture

The design covers every requested component: EC2, RDS PostgreSQL, ALB, IAM,
Security Groups, S3, CloudWatch, Route 53, backups, monitoring, and alerts.

```text
                       Internet / Users
                              |
                         Route 53 DNS  (alias -> ALB)
                              |
                         HTTPS :443
                              |
                    Application Load Balancer  (TLS termination)
                              |
                  Target Group / Health Check /health
                              |
                 +---------------------------+
                 | Private App Subnet        |
                 | EC2                       |
                 | Nginx -> Gunicorn         |
                 | Flask application         |
                 +---------------------------+
                       |                |
                  SG : 5432        IAM Instance Role
                       |                |
                 +-----------+     +---------+
                 | RDS       |     | S3      |
                 | PostgreSQL|     | assets/ |
                 | (private) |     | backups/|
                 +-----------+     +---------+
                       |
                   automated backups

            CloudWatch <- logs + metrics + alarms
            CloudTrail <- AWS API audit
            GitHub Actions -> (OIDC) AWS -> SSM Run Command -> EC2
```

## Route 53
- Hosted zone for the application domain.
- Alias record → ALB (not directly to a single EC2 instance).

## Application Load Balancer
- Public entry point; HTTPS listener on 443 with an ACM certificate.
- HTTP :80 redirects to HTTPS :443.
- Target group with health check path `/health`.

## EC2
- Runs Nginx + Gunicorn + Flask app.
- Placed in a private subnet behind the public ALB.
- Uses an IAM instance role (no static credentials).
- Administered/deployed via SSM (no public SSH required).

## RDS PostgreSQL
- Private subnets; `PubliclyAccessible=false`.
- SG permits inbound 5432 only from the EC2/app SG.
- Automated backups enabled; encryption at rest.
- Multi-AZ is an optional availability upgrade — it raises cost and is not
  required for an assignment demo.

## S3
- Static/media assets, deployment artifacts (optional), and/or backup exports.
- Block public access unless a specific public asset requirement exists.
- Bucket encryption; versioning for important artifacts; IAM scoped to the
  required bucket/prefix.

## CloudWatch
- Collects Nginx logs, application logs, EC2/ALB/RDS metrics.
- Alarms: ALB 5xx rate, unhealthy target count, request latency, EC2 status
  checks, RDS CPU/storage/connections, application error count.
- Note: OS-level memory/disk metrics require the CloudWatch agent; they are not
  emitted by default.

## Security Groups (summary)
- Internet → ALB : 443
- ALB → EC2 : app port (e.g. 80/443 to Nginx)
- EC2 → RDS : 5432
- No `0.0.0.0/0` on 22 or 5432.

## Deployment path
GitHub Actions authenticates to AWS with OIDC (short-lived), then uses SSM Run
Command to invoke `deploy.sh` on the tagged instance. No long-lived AWS keys and
no inbound SSH from the internet.

## Cost note
EC2/RDS/ALB/S3/CloudWatch may incur charges depending on account, region,
instance class, and current free-tier eligibility. Verify against current AWS
pricing before provisioning. This repository is complete without live
infrastructure.
