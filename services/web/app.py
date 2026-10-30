import json
import os
import socket
import urllib.request

from flask import Flask, jsonify

APP_VERSION = os.environ.get("APP_VERSION", "dev")
API_URL = os.environ.get("API_URL", "http://api:5000")


def fetch_hits():
    """Ask the api service (via its Swarm service name) for the visit counter."""
    with urllib.request.urlopen(f"{API_URL}/api/hits", timeout=3) as resp:
        return json.loads(resp.read().decode())


def create_app(fetch=fetch_hits):
    app = Flask(__name__)

    @app.get("/")
    def index():
        try:
            data = fetch()
            line = f"Visits: <b>{data['hits']}</b> (counted by api container <code>{data['hostname']}</code>)"
        except Exception:
            line = "The api service is not reachable right now."
        return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Cloud Computing Project</title>
<style>body{{font-family:system-ui,sans-serif;max-width:38rem;margin:3rem auto;line-height:1.6}}
code{{background:#eef2f5;padding:.1rem .35rem;border-radius:4px}}</style></head>
<body>
<h1>Cloud Computing Project</h1>
<p>GitHub &rarr; Jenkins &rarr; Docker Hub &rarr; Docker Swarm on EC2 (Terraform)</p>
<p>{line}</p>
<p>Web container: <code>{socket.gethostname()}</code> &middot; version <code>{APP_VERSION}</code></p>
</body></html>"""

    @app.get("/health")
    def health():
        return jsonify(status="ok", service="web", version=APP_VERSION)

    return app


app = create_app()
