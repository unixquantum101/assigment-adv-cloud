from app import create_app


def test_index_shows_counter():
    client = create_app(lambda: {"hits": 7, "hostname": "api-1"}).test_client()
    resp = client.get("/")
    assert resp.status_code == 200
    assert b"7" in resp.data


def test_index_survives_api_failure():
    def broken():
        raise OSError("api down")

    resp = create_app(broken).test_client().get("/")
    assert resp.status_code == 200
    assert b"not reachable" in resp.data


def test_health():
    resp = create_app(lambda: {}).test_client().get("/health")
    assert resp.get_json()["service"] == "web"
