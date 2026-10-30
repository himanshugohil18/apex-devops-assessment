# Apex Operations API — DevOps Assessment

A containerized FastAPI application demonstrating Docker packaging, automated testing, CI, local deployment, monitoring, versioned releases, and rollback.

## 1. Architecture

The application runs with PostgreSQL, Prometheus, and Grafana using Docker Compose.

Main components:

- FastAPI: HTTP API, health checks, readiness checks, and metrics.
- PostgreSQL 17: persistent relational database.
- Prometheus: metrics collection and alert evaluation.
- Grafana: monitoring dashboards.
- GitHub Actions: linting, testing, and Docker image build.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the detailed architecture.

## 2. Technology Stack

- Python 3.12
- FastAPI and Uvicorn
- PostgreSQL 17
- Docker and Docker Compose
- GitHub Actions
- Prometheus and Grafana
- Pytest and Ruff

## 3. Project Structure

    apex-devops-assessment/
    ├── app/
    │   └── main.py
    ├── tests/
    │   └── test_api.py
    ├── monitoring/
    │   ├── prometheus.yml
    │   └── alerts.yml
    ├── scripts/
    │   ├── release.sh
    │   ├── rollback.sh
    │   └── project-audit.sh
    ├── evidence/
    ├── .github/workflows/ci.yaml
    ├── Dockerfile
    ├── compose.yaml
    ├── requirements.txt
    ├── requirements-dev.txt
    ├── README.md
    ├── RUNBOOK.md
    ├── DECISIONS.md
    ├── ARCHITECTURE.md
    └── AI-USE.md

## 4. Prerequisites

- Docker Engine or Docker Desktop with Docker Compose.
- Git.
- Python 3.12 for local test execution.

Verify the installations:

    docker --version
    docker compose version
    docker info

## 5. Environment Configuration

Create a `.env` file in the project root with the following variables:

    APP_VERSION=1.0.2
    PREVIOUS_VERSION=1.0.1
    DB_PASSWORD=replace_with_a_strong_password
    GRAFANA_PASSWORD=replace_with_a_strong_password

Use strong passwords. Never commit `.env` or share its contents.

## 6. Start the Application

Build and start the services:

    docker compose up -d --build

Check service status:

    docker compose ps

View application logs:

    docker compose logs -f api

View all service logs:

    docker compose logs

Stop services:

    docker compose down

Do not use `docker compose down -v` for routine shutdown because it removes named volumes.

## 7. Local Service URLs

These are the host ports configured in `compose.yaml`:

| Service | URL |
|---|---|
| API | http://localhost:8002 |
| API health | http://localhost:8002/health |
| API readiness | http://localhost:8002/ready |
| Prometheus | http://localhost:9091 |
| Grafana | http://localhost:3001 |

PostgreSQL is accessible internally to the Compose network and is not published to a host port.

Grafana credentials are configured through `.env`.

## 8. API Endpoints

| Endpoint | Purpose |
|---|---|
| GET / | Service information and version |
| GET /health | Application liveness |
| GET /ready | Database dependency readiness |
| GET /metrics | Prometheus metrics |

Check API health:

    curl -i http://localhost:8002/health

Check API readiness:

    curl -i http://localhost:8002/ready

Inspect metrics:

    curl http://localhost:8002/metrics

The readiness endpoint checks PostgreSQL connectivity and returns HTTP 503 when the dependency is unavailable.

## 9. Automated Tests and Linting

Create and activate a virtual environment:

    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements-dev.txt

Run linting:

    ruff check app tests

Run tests:

    PYTHONPATH=. pytest -v

The current test suite covers service information, version reporting, health, readiness, Prometheus output, request counts, and request duration.

## 10. Continuous Integration

Workflow: `.github/workflows/ci.yaml`

The configured GitHub Actions workflow:

1. Checks out the source.
2. Sets up Python 3.12.
3. Installs development dependencies.
4. Audits application dependencies using pip-audit.
5. Runs Ruff lint checks.
6. Runs Pytest.
7. Builds the Docker image.
8. Scans the image using Trivy for HIGH and CRITICAL vulnerabilities.

Lint and test failures prevent the subsequent image build step.

A local test result does not prove that GitHub Actions has passed. Verify the actual workflow run in the GitHub Actions tab after pushing the repository.

## 11. Monitoring and Alerting

Prometheus scrapes the API metrics endpoint every 15 seconds.

Configuration files:

- `monitoring/prometheus.yml`
- `monitoring/alerts.yml`

Configured alert rules:

| Alert | Condition | Pending period |
|---|---|---|
| ApexAPIDown | API scrape target is down | 1 minute |
| ApexHigh5xxErrorRate | HTTP 5xx ratio exceeds 2% | 5 minutes |
| ApexHighP95Latency | p95 latency exceeds 500 ms | 5 minutes |

Grafana uses the internal Prometheus service URL:

    http://prometheus:9090

Useful PromQL queries:

API availability:

    up{job="apex-api"}

Request rate:

    sum(rate(http_requests_total[5m]))

5xx error rate:

    100 * sum(rate(http_requests_total{status_code=~"5.."}[5m]))
    / clamp_min(sum(rate(http_requests_total[5m])), 0.001)

p95 latency:

    histogram_quantile(
      0.95,
      sum by (le) (
        rate(http_request_duration_seconds_bucket{job="apex-api"}[5m])
      )
    )

## 12. Versioned Release

The release script builds and validates a versioned Docker image before deploying it.

Example:

    ./scripts/release.sh 1.0.3

The script:

1. Validates the semantic version.
2. Builds a versioned image.
3. Starts a temporary validation container.
4. Checks the new image health endpoint.
5. Records the previous version.
6. Deploys the new version.
7. Checks deployment health.
8. Attempts to restore the previous version if deployment validation fails.

## 13. Rollback

Execute:

    ./scripts/rollback.sh

The rollback script deploys the recorded previous image and validates its health. If rollback validation fails, it attempts to restore the original version.

Keep previous release images available until they are no longer needed for recovery.

## 14. Security Practices

- The API container runs as a non-root user.
- Credentials are supplied through environment configuration.
- `.env` must not be committed.
- Prometheus configuration is mounted read-only.
- Grafana self-registration is disabled.
- Host-facing service ports are bound to localhost.
- CI repository contents permission is read-only.

Dependency vulnerability auditing with pip-audit and container image scanning with Trivy are included in CI. Production use still requires ongoing security review.

## 15. Evidence

The `evidence/` directory contains assessment evidence, including:

- Intentional test failure output.
- Versioned release output.
- Rollback output.

Additional CI, monitoring, deployment, and alert-recovery evidence should be added only after the corresponding results are verified.

## 16. Production Considerations

This project is a local assessment environment, not a production deployment.

Potential production improvements include:

- Managed secret storage.
- Automated dependency and container image scanning.
- TLS and authenticated monitoring access.
- Centralized logging and retention.
- Database backup and restore testing.
- Resource limits and capacity planning.
- Remote image registry and immutable image digests.
- Deployment approvals and protected environments.

## 17. Related Documentation

- [Operations Runbook](RUNBOOK.md)
- [Architecture](ARCHITECTURE.md)
- [Technical Decisions](DECISIONS.md)
- [AI Assistance Disclosure](AI-USE.md)
