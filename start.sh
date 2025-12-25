#!/bin/bash
set -e

echo "Creating migrations..."
python manage.py makemigrations || true

echo "Applying migrations..."
python manage.py migrate --noinput

echo "Seeding data..."
python manage.py seed_data || echo "Seed data already exists or failed"

echo "Starting server with WebSocket support..."
uvicorn BrightEat.asgi:application --host 0.0.0.0 --port 8000

