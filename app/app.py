import os
import socket
import time

from flask import Flask, jsonify

app = Flask(__name__)

START_TIME = time.time()
VERSION = os.getenv("APP_VERSION", "dev")


@app.get("/")
def index():
    return jsonify(
        message="Hello from the Flask CI/CD demo",
        version=VERSION,
        hostname=socket.gethostname(),
    )


@app.get("/health")
def health():
    return jsonify(status="ok", uptime_seconds=round(time.time() - START_TIME, 1)), 200


if __name__ == "__main__":
    # Local development only. In the container, gunicorn runs the app.
    app.run(host="127.0.0.1", port=8000)
