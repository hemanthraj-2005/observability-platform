from app import app


def test_home_endpoint_returns_application_status():
    client = app.test_client()

    response = client.get("/")

    assert response.status_code == 200
    assert response.data == b"Application running"


def test_health_endpoint_returns_ok():
    client = app.test_client()

    response = client.get("/health")

    assert response.status_code == 200
    assert response.data == b"OK"


def test_error_endpoint_returns_500():
    client = app.test_client()

    response = client.get("/error")

    assert response.status_code == 500
    assert response.data == b"Error generated"


def test_metrics_endpoint_exposes_custom_metrics():
    client = app.test_client()

    response = client.get("/metrics")
    body = response.data.decode()

    assert response.status_code == 200
    assert "flask_http_requests_total" in body
    assert "flask_http_errors_total" in body
    assert "flask_http_request_duration_seconds" in body
