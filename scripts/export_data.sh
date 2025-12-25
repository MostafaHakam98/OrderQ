#!/bin/bash

# Script to export data from source node
# Usage: ./export_data.sh [export_directory]
# Example: ./export_data.sh /tmp/brighteat_export

set -e

EXPORT_DIR="${1:-./brighteat_export_$(date +%Y%m%d_%H%M%S)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================="
echo "BrightEat Data Export Script"
echo "========================================="
echo "Export directory: $EXPORT_DIR"
echo ""

# Create export directory
mkdir -p "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR/media"
mkdir -p "$EXPORT_DIR/database"

cd "$PROJECT_ROOT"

# Check if Docker Compose is running
if ! docker-compose ps | grep -q "Up"; then
    echo "Warning: Docker Compose services don't appear to be running."
    echo "Attempting to export anyway..."
fi

# Export PostgreSQL database
echo "Step 1: Exporting PostgreSQL database..."
DB_CONTAINER=$(docker-compose ps -q db 2>/dev/null || echo "")

if [ -n "$DB_CONTAINER" ]; then
    echo "Found database container: $DB_CONTAINER"
    docker-compose exec -T db pg_dump -U postgres brighteat > "$EXPORT_DIR/database/brighteat_dump.sql"
    echo "✓ Database exported to $EXPORT_DIR/database/brighteat_dump.sql"
else
    echo "⚠ Database container not found. If using external database, export manually:"
    echo "   pg_dump -h <HOST> -U postgres brighteat > $EXPORT_DIR/database/brighteat_dump.sql"
fi

# Copy media files
echo ""
echo "Step 2: Copying media files..."
if [ -d "media" ]; then
    cp -r media/* "$EXPORT_DIR/media/" 2>/dev/null || true
    echo "✓ Media files copied to $EXPORT_DIR/media/"
else
    echo "⚠ Media directory not found"
fi

# Export Redis data (optional)
echo ""
echo "Step 3: Exporting Redis data (optional)..."
REDIS_CONTAINER=$(docker-compose ps -q redis 2>/dev/null || echo "")

if [ -n "$REDIS_CONTAINER" ]; then
    echo "Found Redis container: $REDIS_CONTAINER"
    docker-compose exec -T redis redis-cli --rdb "$EXPORT_DIR/redis_dump.rdb" 2>/dev/null || \
    docker-compose exec -T redis redis-cli SAVE > /dev/null 2>&1 && \
    docker cp "$REDIS_CONTAINER:/data/dump.rdb" "$EXPORT_DIR/redis_dump.rdb" 2>/dev/null || \
    echo "⚠ Redis export failed (this is optional)"
    
    if [ -f "$EXPORT_DIR/redis_dump.rdb" ]; then
        echo "✓ Redis data exported to $EXPORT_DIR/redis_dump.rdb"
    fi
else
    echo "⚠ Redis container not found. Skipping Redis export."
fi

# Create environment template
echo ""
echo "Step 4: Creating environment configuration template..."
cat > "$EXPORT_DIR/env_template.txt" << 'EOF'
# Environment Variables Template
# Copy these to your .env file or docker-compose.yml on the destination node
# Update the values as needed for the new server

SECRET_KEY=your-secret-key-here
DEBUG=False
DB_NAME=brighteat
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=db
DB_PORT=5432
FRONTEND_URL=http://YOUR_NEW_IP:19991
REDIS_HOST=redis
REDIS_PORT=6379
CSRF_TRUSTED_ORIGINS=http://YOUR_NEW_IP:19991,http://localhost:19991
CITE_API_BASE_URL=your-cite-api-url
CELERY_BROKER_URL=redis://redis:6379/0
CELERY_RESULT_BACKEND=redis://redis:6379/0
EOF

echo "✓ Environment template created at $EXPORT_DIR/env_template.txt"

# Create README with instructions
echo ""
echo "Step 5: Creating migration README..."
cat > "$EXPORT_DIR/README_MIGRATION.md" << 'EOF'
# BrightEat Data Migration

This directory contains exported data from the source node.

## Contents

- `database/brighteat_dump.sql` - PostgreSQL database dump
- `media/` - Media files (QR codes, uploaded images, etc.)
- `redis_dump.rdb` - Redis data dump (optional)
- `env_template.txt` - Environment variables template
- `README_MIGRATION.md` - This file

## Migration Steps

### On Destination Node:

1. **Transfer this entire directory to the destination node:**
   ```bash
   # Using SCP (from source node)
   scp -r brighteat_export_* user@DESTINATION_IP:/path/to/BrightEat/
   
   # Or using rsync
   rsync -avz brighteat_export_* user@DESTINATION_IP:/path/to/BrightEat/
   ```

2. **On the destination node, run the import script:**
   ```bash
   cd /path/to/BrightEat
   chmod +x scripts/import_data.sh
   ./scripts/import_data.sh brighteat_export_*
   ```

3. **Update environment variables:**
   - Copy `env_template.txt` to `.env` or update `docker-compose.yml`
   - Update IP addresses and URLs for the new server
   - Update `SECRET_KEY` if needed

4. **Start the services:**
   ```bash
   docker-compose up -d
   ```

5. **Verify the migration:**
   - Check that the database has data: `docker-compose exec db psql -U postgres -d brighteat -c "SELECT COUNT(*) FROM orders_user;"`
   - Check media files are accessible
   - Test the application

## Manual Migration (if scripts don't work)

### Database:
```bash
# On destination node
docker-compose exec -T db psql -U postgres brighteat < database/brighteat_dump.sql
```

### Media Files:
```bash
# Copy media files to the media directory
cp -r media/* /path/to/BrightEat/media/
```

### Redis (optional):
```bash
# Copy Redis dump to container
docker cp redis_dump.rdb $(docker-compose ps -q redis):/data/dump.rdb
docker-compose restart redis
```
EOF

echo "✓ Migration README created at $EXPORT_DIR/README_MIGRATION.md"

# Create archive
echo ""
echo "Step 6: Creating compressed archive..."
cd "$(dirname "$EXPORT_DIR")"
ARCHIVE_NAME="$(basename "$EXPORT_DIR").tar.gz"
tar -czf "$ARCHIVE_NAME" "$(basename "$EXPORT_DIR")" 2>/dev/null || {
    echo "⚠ Could not create archive (tar may not be available)"
    echo "You can manually create an archive or transfer the directory as-is"
}

if [ -f "$ARCHIVE_NAME" ]; then
    echo "✓ Archive created: $ARCHIVE_NAME"
    echo "  Size: $(du -h "$ARCHIVE_NAME" | cut -f1)"
fi

echo ""
echo "========================================="
echo "Export completed successfully!"
echo "========================================="
echo ""
echo "Export location: $EXPORT_DIR"
if [ -f "$ARCHIVE_NAME" ]; then
    echo "Archive: $ARCHIVE_NAME"
fi
echo ""
echo "Next steps:"
echo "1. Transfer the export directory/archive to the destination node"
echo "2. Run the import script on the destination node"
echo "3. See README_MIGRATION.md for detailed instructions"
echo ""

