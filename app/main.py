import logging
import os
import time
from contextlib import asynccontextmanager

import psycopg
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("apex-api")

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status_code"],
)

REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "path"],
)

HTTP_ERRORS = Counter(
    "http_errors_total",
    "Total HTTP error responses",
    ["status_code"],
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API starting")
    yield
    logger.info("API stopping")


app = FastAPI(
    title="Apex Operations API",
    version=os.getenv("APP_VERSION", "1.0.0"),
    lifespan=lifespan,
)


@app.middleware("http")
async def observe_requests(request: Request, call_next):
    start_time = time.perf_counter()
    status_code = 500

    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    except Exception:
        logger.exception("Unhandled request error")
        raise
    finally:
        path = request.url.path
        method = request.method

        REQUEST_COUNT.labels(
            method=method,
            path=path,
            status_code=str(status_code),
        ).inc()

        REQUEST_DURATION.labels(
            method=method,
            path=path,
        ).observe(time.perf_counter() - start_time)

        if status_code >= 400:
            HTTP_ERRORS.labels(status_code=str(status_code)).inc()


@app.get("/")
def root():
    return {
        "service": "apex-operations-api",
        "version": os.getenv("APP_VERSION", "1.0.0"),
    }


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "database_not_configured"},
        )

    try:
        with psycopg.connect(database_url, connect_timeout=2) as connection:
            connection.execute("SELECT 1")

        return {"status": "ready", "database": "connected"}

    except Exception:
        logger.exception("Readiness check failed")
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "dependency_unavailable"},
        )


@app.get("/metrics", include_in_schema=False)
def metrics():
    return Response(
        content=generate_latest(),
        media_type=CONTENT_TYPE_LATEST,
    )
