# syntax=docker/dockerfile:1

# ---------- Stage 1: shared base with runtime dependencies ----------
FROM python:3.11-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Copy only the requirements first so Docker caches the pip layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------- Stage 2: test image (adds pytest + flake8) ----------
FROM base AS test

COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt

COPY . .

ENV ACEEST_DB=/tmp/test.db
CMD ["pytest", "-v", "--cov=.", "--cov-report=term-missing"]

# ---------- Stage 3: lean production runtime ----------
FROM base AS runtime

# Run as an unprivileged user
RUN useradd --create-home --shell /usr/sbin/nologin aceest

COPY --chown=aceest:aceest app.py db.py models.py ./
COPY --chown=aceest:aceest templates/ ./templates/
COPY --chown=aceest:aceest static/ ./static/

USER aceest

ENV PORT=5000 \
    ACEEST_DB=/tmp/aceest_fitness.db

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health').status==200 else 1)"

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
