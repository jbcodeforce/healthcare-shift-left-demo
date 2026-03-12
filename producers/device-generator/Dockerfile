# Device telemetry generator microservice (FastAPI + Confluent Kafka producer)
FROM python:3.12-slim

WORKDIR /app

# Install uv for fast, reproducible installs
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Dependencies first (better layer cache)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Application (README.md required by hatchling for build)
COPY src ./src
COPY README.md ./
RUN uv sync --frozen --no-dev

# Non-root user
RUN useradd -m -u 1000 app && chown -R app:app /app
USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uv", "run", "uvicorn", "device_generator.main:app", "--host", "0.0.0.0", "--port", "8000"]
