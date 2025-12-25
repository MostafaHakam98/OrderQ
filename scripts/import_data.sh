#!/bin/bash

# Script to import data to destination node
# Usage: ./import_data.sh <export_directory>
# Example: ./import_data.sh ./brighteat_export_20240101_120000

set -e

if [ -z "$1" ]; then
    echo "Error: Export directory not specified"
    echo "Usage: $0 <export_directory>"
    echo "Example: $0 ./brighteat_export_20240101_120000"
    exit 1
fi

EXPORT_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if export directory exists
if [ ! -d "$EXPORT_DIR" ]; then
    # Try relative to project root
    EXPORT_DIR="$PROJECT_ROOT/$1"
    if [ ! -d "$EXPORT_DIR" ]; then
        echo "Error: Export directory not found: $1"
        exit 1
    fi
fi

echo "========================================="
echo "BrightEat Data Import Script"
echo "========================================="
echo "Import directory: $EXPORT_DIR"
echo "Project root: $PROJECT_ROOT"
echo ""

cd "$PROJECT_ROOT"

# Check if docker compose  is available
if ! command -v docker compose &> /dev/null; then
    echo "Error: docker compose not found. Please install docker compose ."
    exit 1
fi

# Check if services are running
echo "Checking docker compose  services..."
if ! docker compose ps | grep -q "Up"; then
    echo "Warning: docker compose  services are not running."
    echo "Starting services..."
    docker compose up -d db redis
    echo "Waiting for services to be ready..."
    sleep 10
fi

# Import PostgreSQL database
echo ""
echo "Step 1: Importing PostgreSQL database..."
DB_CONTAINER=$(docker compose ps -q db 2>/dev/null || echo "")

if [ -z "$DB_CONTAINER" ]; then
    echo "Error: Database container not found. Please start docker compose  services first."
    exit 1
fi

DB_DUMP="$EXPORT_DIR/database/brighteat_dump.sql"
if [ ! -f "$DB_DUMP" ]; then
    echo "Error: Database dump not found: $DB_DUMP"
    exit 1
fi

echo "Found database container: $DB_CONTAINER"
echo "Importing database dump..."

# Drop existing database and recreate (optional - comment out if you want to merge)
echo "⚠ Warning: This will replace the existing database."
read -p "Do you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Import cancelled."
    exit 0
fi

# Create database if it doesn't exist
docker compose exec -T db psql -U postgres -c "DROP DATABASE IF EXISTS brighteat;" 2>/dev/null || true
docker compose exec -T db psql -U postgres -c "CREATE DATABASE brighteat;" 2>/dev/null || true

# Import the dump
docker compose exec -T db psql -U postgres brighteat < "$DB_DUMP"
echo "✓ Database imported successfully"

# Import media files
echo ""
echo "Step 2: Importing media files..."
if [ -d "$EXPORT_DIR/media" ]; then
    # Create media directory if it doesn't exist
    mkdir -p "$PROJECT_ROOT/media"
    
    # Copy media files
    cp -r "$EXPORT_DIR/media/"* "$PROJECT_ROOT/media/" 2>/dev/null || true
    echo "✓ Media files imported to $PROJECT_ROOT/media/"
    
    # Set proper permissions
    chmod -R 755 "$PROJECT_ROOT/media" 2>/dev/null || true
else
    echo "⚠ Media directory not found in export"
fi

# Import Redis data (optional)
echo ""
echo "Step 3: Importing Redis data (optional)..."
REDIS_DUMP="$EXPORT_DIR/redis_dump.rdb"
if [ -f "$REDIS_DUMP" ]; then
    REDIS_CONTAINER=$(docker compose ps -q redis 2>/dev/null || echo "")
    if [ -n "$REDIS_CONTAINER" ]; then
        echo "Found Redis container: $REDIS_CONTAINER"
        # Stop Redis to import data
        docker compose stop redis
        # Copy dump file
        docker cp "$REDIS_DUMP" "$REDIS_CONTAINER:/data/dump.rdb"
        # Restart Redis
        docker compose start redis
        echo "✓ Redis data imported"
    else
        echo "⚠ Redis container not found. Skipping Redis import."
    fi
else
    echo "⚠ Redis dump not found. Skipping Redis import (this is optional)."
fi

# Run migrations (in case schema changed)
echo ""
echo "Step 4: Running database migrations..."
docker compose exec -T backend python manage.py migrate --noinput 2>/dev/null || {
    echo "⚠ Could not run migrations automatically. Run manually:"
    echo "   docker compose exec backend python manage.py migrate"
}

# Collect static files
echo ""
echo "Step 5: Collecting static files..."
docker compose exec -T backend python manage.py collectstatic --noinput 2>/dev/null || {
    echo "⚠ Could not collect static files automatically. Run manually:"
    echo "   docker compose exec backend python manage.py collectstatic --noinput"
}

echo ""
echo "========================================="
echo "Import completed successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Update environment variables in docker-compose.yml or .env file"
echo "2. Update IP addresses and URLs for the new server"
echo "3. Restart services: docker compose restart"
echo "4. Verify the migration by checking the application"
echo ""

