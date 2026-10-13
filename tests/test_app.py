from app import app


def client():
    app.config["TESTING"] = True
    return app.test_client()


def test_health_returns_ok():
    response = client().get("/health")
    assert response.status_code == 200
    body = response.get_json()
    assert body["status"] == "ok"
    assert body["uptime_seconds"] >= 0


def test_index_returns_message_and_version():
    response = client().get("/")
    assert response.status_code == 200
    body = response.get_json()
    assert "message" in body
    assert "version" in body
    assert "hostname" in body


def test_unknown_route_returns_404():
    assert client().get("/does-not-exist").status_code == 404
