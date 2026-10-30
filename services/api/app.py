import os
import socket

import redis
from flask import Flask, jsonify

APP_VERSION = os.environ.get("APP_VERSION", "dev")


def create_app(cache=None):
    """Application factory; `cache` can be replaced by a fake in tests."""
    app = Flask(__name__)
    if cache is None:
        cache = redis.Redis(
            host=os.environ.get("REDIS_HOST", "redis"),
            port=int(os.environ.get("REDIS_PORT", "6379")),
            socket_connect_timeout=2,
        )

    @app.get("/api/health")
    def health():
        return jsonify(status="ok", service="api", version=APP_VERSION)

    @app.get("/api/info")
    def info():
        # hostname differs per replica -> proves load balancing across tasks
        return jsonify(service="api", hostname=socket.gethostname(), version=APP_VERSION)

    @app.get("/api/hits")
    def hits():
        try:
            count = cache.incr("hits")
        except redis.exceptions.RedisError:
            return jsonify(error="redis unavailable"), 503
        return jsonify(hits=int(count), hostname=socket.gethostname())

    return app


app = create_app()
