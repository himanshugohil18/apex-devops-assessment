# Architecture and Technical Decision Record

## 1. Project Context

The Apex Operations API assessment demonstrates containerization, CI, deployment safety, observability, security, and operational recovery.

The following decisions document the selected technologies and their trade-offs.

## 2. Decision: FastAPI and Python 3.12

**Selected:** FastAPI with Python 3.12.

**Reasoning:**
- Lightweight API framework.
- Built-in support for health and readiness endpoints.
- Straightforward integration with Prometheus metrics.
- Python ecosystem provides mature testing and linting tools.

**Trade-offs:**
- Python runtime performance may be lower than compiled languages for CPU-intensive workloads.
- Dependency versions must be maintained and audited.

## 3. Decision: Docker Containerization

**Selected:** Docker with python:3.12-slim.

**Reasoning:**
- Reproducible application packaging.
- Smaller base image than a full Python distribution.
- Consistent runtime across development and deployment environments.

**Security decisions:**
- Application runs as a non-root user.
- Python bytecode generation is disabled.
- Unbuffered output supports container log collection.

**Trade-offs:**
- Container images require regular rebuilding and vulnerability checks.
- Slim images may require additional system packages for certain dependencies.

## 4. Decision: Docker Compose

**Selected:** Docker Compose for local multi-service orchestration.

**Reasoning:**
- Runs API, PostgreSQL, Prometheus, and Grafana together.
- Supports service dependencies and health checks.
- Named volumes provide persistence for service data.
- Environment variables separate configuration from application code.

**Trade-offs:**
- Suitable for local assessment and development, not a replacement for production orchestration.
- High availability and multi-host scheduling require additional infrastructure.

## 5. Decision: PostgreSQL

**Selected:** PostgreSQL 17.

**Reasoning:**
- Mature relational database.
- Supports persistent application data.
- Provides health checks through pg_isready.

**Trade-offs:**
- Requires backup, recovery, storage, and upgrade planning.
- A single local database container is not highly available.

## 6. Decision: GitHub Actions

**Selected:** GitHub Actions for continuous integration.

**Pipeline stages:**
1. Checkout source.
2. Configure Python 3.12.
3. Install dependencies.
4. Run Ruff linting.
5. Execute automated tests.
6. Build the Docker image.

**Reasoning:**
- Automated validation on push and pull requests.
- Failed lint or test stages block the image build step.
- Workflow is version-controlled with application code.

**Trade-offs:**
- Workflow execution depends on GitHub-hosted runners.
- Deployment approval and protected environments would be needed for a production release pipeline.

## 7. Decision: Pytest and Ruff

**Selected:** Pytest for automated testing and Ruff for linting.

**Reasoning:**
- Fast automated feedback.
- Detects regressions and code-quality issues.
- Supports CI integration.

**Trade-offs:**
- Unit tests cannot replace integration, load, or security testing.
- Test coverage should grow with application functionality.

## 8. Decision: Prometheus and Grafana

**Selected:** Prometheus for metrics collection and Grafana for visualization.

**Metrics:**
- HTTP request count.
- HTTP error count.
- Request duration histogram.

**Alerts:**
- API unavailable.
- HTTP 5xx error rate above 2%.
- p95 latency above 500 milliseconds.

**Reasoning:**
- Open-source monitoring stack.
- PromQL supports metric analysis and alert expressions.
- Grafana provides operational dashboards.

**Trade-offs:**
- Metrics require storage retention and capacity planning.
- Alert thresholds need tuning against real service baselines.
- Metrics alone do not provide distributed tracing.

## 9. Decision: Health and Readiness Checks

**Selected endpoints:**
- `/health` for application liveness.
- `/ready` for database dependency readiness.

**Reasoning:**
- Separates application process health from dependency availability.
- Helps Docker Compose and operators detect service failures.
- Readiness checks validate PostgreSQL connectivity.

**Trade-offs:**
- Dependency checks introduce additional database connections.
- Health endpoints should remain lightweight.

## 10. Decision: Versioned Releases and Rollback

**Selected:** Semantic version tags and shell-based release/rollback scripts.

**Release approach:**
- Build a versioned image.
- Validate the image in a temporary container.
- Update the application version.
- Deploy and verify container health.
- Restore the previous version if deployment validation fails.

**Rollback approach:**
- Store the previous version in environment configuration.
- Deploy the previous image.
- Verify health before considering rollback successful.

**Trade-offs:**
- Local image retention consumes disk space.
- This mechanism does not replace a registry-backed immutable artifact pipeline.
- Database schema migrations would need independent backward-compatibility planning.

## 11. Security Decisions

- Use a non-root application container user.
- Keep credentials in environment configuration.
- Exclude `.env` from version control.
- Use read-only monitoring configuration mounts.
- Disable Grafana user self-registration.
- Limit GitHub Actions repository permissions to read-only contents.

**Future improvements:**
- Automated dependency scanning.
- Container image scanning.
- Secret management service.
- Image signing and provenance verification.
- TLS and authenticated monitoring access.

## 12. Cost Decisions

The assessment uses local Docker services to avoid paid cloud infrastructure.

Production alternatives could include managed database, container registry, centralized monitoring, and managed orchestration services.

Cloud resource sizing, retention policies, and autoscaling should be based on measured workload requirements.

## 13. Final Decision Summary

The selected architecture prioritizes:
- Reproducible deployments.
- Simple local operation.
- Automated quality checks.
- Observable application behavior.
- Recoverable versioned releases.
- Basic container security.

These decisions provide a practical foundation while clearly identifying the additional controls required before production deployment.
