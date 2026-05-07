import logging
import time

from flask import Flask, Response, request
from prometheus_client import Counter, Histogram, generate_latest

app = Flask(__name__)

logging.basicConfig(level=logging.INFO)

REQUEST_COUNT = Counter(
    "flask_http_requests_total",
    "Total HTTP requests handled by the Flask application.",
    ["method", "endpoint", "http_status"],
)

REQUEST_LATENCY = Histogram(
    "flask_http_request_duration_seconds",
    "HTTP request latency for the Flask application.",
    ["method", "endpoint"],
)

ERROR_COUNT = Counter(
    "flask_http_errors_total",
    "Total simulated application errors.",
    ["endpoint"],
)


@app.before_request
def start_timer():
    request.start_time = time.time()


@app.after_request
def record_request_metrics(response):
    if request.path != "/metrics":
        endpoint = request.endpoint or "unknown"
        REQUEST_COUNT.labels(request.method, endpoint, response.status_code).inc()
        REQUEST_LATENCY.labels(request.method, endpoint).observe(time.time() - request.start_time)

    return response


@app.route("/")
def home():
    app.logger.info("Home endpoint was accessed")
    return "Application running"


@app.route("/error")
def error():
    app.logger.error("Simulated application error occurred")
    ERROR_COUNT.labels("error").inc()
    return "Error generated", 500


@app.route("/health")
def health():
    return "OK", 200


@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
