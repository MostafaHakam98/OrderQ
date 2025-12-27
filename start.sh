#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database to be ready..."
until PGPASSWORD=${DB_PASSWORD:-postgres} psql -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -c '\q' 2>/dev/null; do
  echo "Database is unavailable - sleeping"
  sleep 1
done

# Create database if it doesn't exist
echo "Ensuring database exists..."
DB_NAME=${DB_NAME:-orderq}
PGPASSWORD=${DB_PASSWORD:-postgres} psql -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1 || \
PGPASSWORD=${DB_PASSWORD:-postgres} psql -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" -d postgres -c "CREATE DATABASE ${DB_NAME}"

echo "Creating migrations..."
python manage.py makemigrations || true

echo "Applying migrations..."
python manage.py migrate --noinput

echo "Seeding data..."
python manage.py seed_data || echo "Seed data already exists or failed"

echo "Starting server with WebSocket support..."
uvicorn OrderQ.asgi:application --host 0.0.0.0 --port 8000

