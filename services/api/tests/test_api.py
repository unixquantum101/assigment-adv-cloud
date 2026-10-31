import redis

from app import create_app


class FakeCache:
    def __init__(self):
        self.value = 0

    def incr(self, key):
        self.value += 1
        return self.value


class BrokenCache:
    def incr(self, key):
        raise redis.exceptions.ConnectionError("down")


def test_health_ok():
    client = create_app(FakeCache()).test_client()
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "ok"


def test_info_reports_hostname():
    client = create_app(FakeCache()).test_client()
    data = client.get("/api/info").get_json()
    assert data["service"] == "api"
    assert data["hostname"]


def test_hits_counts_up():
    client = create_app(FakeCache()).test_client()
    assert client.get("/api/hits").get_json()["hits"] == 1
    assert client.get("/api/hits").get_json()["hits"] == 2


def test_hits_returns_503_when_redis_down():
    client = create_app(BrokenCache()).test_client()
    assert client.get("/api/hits").status_code == 503
