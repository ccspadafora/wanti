#!/bin/bash
set -e

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"

echo "▶ Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" > /dev/null 2>&1; do
  sleep 1
done
echo "✓ PostgreSQL ready"

if [ "$RUN_MIGRATIONS" = "true" ]; then
  echo "▶ Running migrations..."
  python manage.py migrate --noinput
  echo "▶ Collecting static files..."
  python manage.py collectstatic --noinput --clear || true
fi

exec "$@"
