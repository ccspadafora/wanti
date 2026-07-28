FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libgdal-dev \
    gdal-bin \
    libgeos-dev \
    libproj-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-warn-script-location -r requirements.txt

FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/app/.local/bin:$PATH \
    DJANGO_SETTINGS_MODULE=app.settings.production

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    gdal-bin \
    libgeos-c1v5 \
    libproj25 \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    || (apt-get update && apt-get install -y --no-install-recommends \
        libpq5 gdal-bin libgeos-c1v5 postgresql-client curl \
        && rm -rf /var/lib/apt/lists/*)

RUN groupadd --system app && useradd --system --gid app --shell /bin/bash --home /home/app app \
    && mkdir -p /home/app/code /home/app/.local \
    && chown -R app:app /home/app

COPY --from=builder --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app . /home/app/code
COPY docker/entrypoint.sh /home/app/entrypoint.sh
RUN chmod +x /home/app/entrypoint.sh \
    && mkdir -p /home/app/code/staticfiles /home/app/code/media \
    && chown -R app:app /home/app

USER app
WORKDIR /home/app/code

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/health/ || exit 1

ENTRYPOINT ["/home/app/entrypoint.sh"]
CMD ["gunicorn", "app.wsgi:application", \
     "--bind", "0.0.0.0:8000", \
     "--workers", "4", \
     "--worker-class", "gthread", \
     "--threads", "2", \
     "--timeout", "60", \
     "--access-logfile", "-", \
     "--error-logfile", "-"]
