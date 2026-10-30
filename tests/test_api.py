from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_service_info():
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["service"] == "apex-operations-api"


def test_root_returns_version():
    response = client.get("/")

    assert response.json()["version"] == "1.0.0"


def test_health_returns_ok():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_response_is_json():
    response = client.get("/health")

    assert response.headers["content-type"].startswith("application/json")


def test_ready_without_database_configuration(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)

    response = client.get("/ready")

    assert response.status_code == 503
    assert response.json()["status"] == "not_ready"


def test_ready_reports_missing_database_reason(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)

    response = client.get("/ready")

    assert response.json()["reason"] == "database_not_configured"


def test_metrics_endpoint_returns_prometheus_format():
    response = client.get("/metrics")

    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    assert "http_requests_total" in response.text


def test_metrics_records_http_requests():
    client.get("/health")

    response = client.get("/metrics")

    assert response.status_code == 200
    assert 'path="/health"' in response.text


def test_metrics_records_request_duration():
    client.get("/")

    response = client.get("/metrics")

    assert response.status_code == 200
    assert "http_request_duration_seconds_count" in response.text
