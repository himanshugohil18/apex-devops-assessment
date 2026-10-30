# Apex Operations API — Operations Runbook

## 1. Purpose

This runbook describes how to deploy, monitor, troubleshoot, and recover the Apex Operations API local assessment environment.

## 2. Service Inventory

| Service | Compose service | Purpose |
|---|---|---|
| API | api | FastAPI application |
| Database | db | PostgreSQL |
| Metrics | prometheus | Metrics collection and alert evaluation |
| Dashboard | grafana | Monitoring visualization |

## 3. Initial Health Check

Check running containers:

    docker compose ps

Check API health:

    curl -i http://localhost:8002/health

Check API readiness:

    curl -i http://localhost:8002/ready

Check recent API logs:

    docker compose logs --tail=100 api

Check database logs:

    docker compose logs --tail=100 db

Check Prometheus targets:

    Open http://localhost:9091/targets

Check Grafana:

    Open http://localhost:3001

## 4. Incident: API Is Unavailable

### Symptoms

- API health endpoint does not respond.
- Container is unhealthy or stopped.
- Prometheus reports API target down.
- Grafana API availability panel reports zero.

### Investigation

    docker compose ps
    docker compose logs --tail=200 api
    docker inspect $(docker compose ps -q api) --format '{{.State.Health.Status}}'

### Recovery

    docker compose up -d api

Verify recovery:

    docker compose ps
    curl -i http://localhost:8002/health
    curl -i http://localhost:8002/ready

Confirm Prometheus target returns to UP.

## 5. Incident: Database Is Unavailable

### Symptoms

- API readiness endpoint returns HTTP 503.
- Logs show readiness check failures.
- PostgreSQL container is unhealthy.

### Investigation

    docker compose ps db
    docker compose logs --tail=200 db

Check database readiness:

    docker compose exec db pg_isready -U appuser -d appdb

### Recovery

    docker compose restart db

Wait for the database health check:

    docker compose ps

Then verify API readiness:

    curl -i http://localhost:8002/ready

Do not remove PostgreSQL volumes during troubleshooting.

## 6. Incident: High HTTP 5xx Error Rate

### Symptoms

- Prometheus alert ApexHigh5xxErrorRate fires.
- Grafana error-rate panel increases.
- API requests return server errors.

### Investigation

    docker compose logs --since=10m api

Check request metrics:

    curl -s http://localhost:8002/metrics

PromQL:

    sum(rate(http_requests_total{status_code=~"5.."}[5m]))
    /
    clamp_min(sum(rate(http_requests_total[5m])), 0.001)

### Recovery

1. Identify the failing endpoint and error.
2. Check recent application logs.
3. Check database readiness and dependency availability.
4. Restore the last known good application version if necessary.
5. Verify error rate returns to normal.

## 7. Incident: High API Latency

### Symptoms

- ApexHighP95Latency alert fires.
- Grafana p95 latency panel increases.
- API responses become slow.

### Investigation

    docker compose logs --since=10m api
    docker stats

PromQL:

    histogram_quantile(
      0.95,
      sum by (le) (
        rate(http_request_duration_seconds_bucket{job="apex-api"}[5m])
      )
    )

### Recovery

1. Check CPU and memory usage.
2. Inspect application logs.
3. Check database availability and query performance.
4. Identify the affected endpoint.
5. Roll back a recent release if the issue began after deployment.
6. Verify latency returns below the configured threshold.

## 8. Release Procedure

Validate the current deployment:

    docker compose ps

Deploy a new semantic version:

    ./scripts/release.sh 1.0.3

Verify the deployed version:

    curl -s http://localhost:8002/

Verify health:

    curl -i http://localhost:8002/health

Check container health:

    docker compose ps api

## 9. Rollback Procedure

Execute:

    ./scripts/rollback.sh

Verify the restored version:

    curl -s http://localhost:8002/

Verify health:

    curl -i http://localhost:8002/health

Check deployment logs:

    docker compose logs --tail=100 api

## 10. Data Protection

PostgreSQL, Prometheus, and Grafana use named Docker volumes.

Important precautions:

- Never run docker compose down -v during routine troubleshooting.
- Never delete database volumes to fix an application issue.
- Verify backup and restore procedures before production use.
- Keep previous application image versions available for rollback.

## 11. Escalation Checklist

Before escalating an incident, collect:

- Incident start time.
- Affected service.
- Container status.
- Relevant application logs.
- Health and readiness responses.
- Prometheus target status.
- Relevant alert state.
- Recent release version.
- Troubleshooting actions already performed.

## 12. Recovery Completion Criteria

An incident is considered recovered after:

- All expected containers are running.
- API health endpoint returns HTTP 200.
- API readiness endpoint returns HTTP 200.
- Prometheus target reports UP.
- Relevant alerts return to normal.
- Application logs show no continuing critical errors.
