# BrightEat Data Migration Guide

This guide explains how to migrate your BrightEat application data from one server/node to another with a different IP address.

## Overview

The migration process involves:
1. **Exporting data** from the source node (database, media files, Redis)
2. **Transferring** the exported data to the destination node
3. **Importing data** on the destination node
4. **Updating configuration** for the new IP address

## Prerequisites

- Access to both source and destination nodes
- Docker and docker compose  installed on both nodes
- SSH access to transfer files (or use alternative methods)
- Sufficient disk space for the export

## Step-by-Step Migration

### Step 1: Export Data from Source Node

1. **SSH into the source node:**
   ```bash
   ssh user@SOURCE_IP
   cd /path/to/BrightEat
   ```

2. **Make the export script executable:**
   ```bash
   chmod +x scripts/export_data.sh
   ```

3. **Run the export script:**
   ```bash
   ./scripts/export_data.sh
   ```
   
   This will create a directory named `brighteat_export_YYYYMMDD_HHMMSS` containing:
   - Database dump (`database/brighteat_dump.sql`)
   - Media files (`media/`)
   - Redis dump (optional, `redis_dump.rdb`)
   - Environment template (`env_template.txt`)
   - Migration README

4. **The script will also create a compressed archive** (`.tar.gz`) for easier transfer.

### Step 2: Transfer Data to Destination Node

Choose one of the following methods:

#### Method A: Using SCP (Secure Copy)
```bash
# From source node
scp -r brighteat_export_* user@DESTINATION_IP:/path/to/BrightEat/

# Or transfer the archive
scp brighteat_export_*.tar.gz user@DESTINATION_IP:/path/to/BrightEat/
```

#### Method B: Using RSYNC (Recommended for large files)
```bash
# From source node
rsync -avz --progress brighteat_export_* user@DESTINATION_IP:/path/to/BrightEat/
```

#### Method C: Using SFTP or File Manager
- Use an SFTP client (FileZilla, WinSCP, etc.)
- Or use cloud storage (Google Drive, Dropbox, etc.) as an intermediary

#### Method D: Extract Archive on Destination
If you transferred a `.tar.gz` file:
```bash
# On destination node
cd /path/to/BrightEat
tar -xzf brighteat_export_*.tar.gz
```

### Step 3: Import Data on Destination Node

1. **SSH into the destination node:**
   ```bash
   ssh user@DESTINATION_IP
   cd /path/to/BrightEat
   ```

2. **Ensure docker compose  services are set up:**
   ```bash
   # Make sure docker-compose.yml is configured
   # Start database and Redis services
   docker compose up -d db redis
   ```

3. **Make the import script executable:**
   ```bash
   chmod +x scripts/import_data.sh
   ```

4. **Run the import script:**
   ```bash
   ./scripts/import_data.sh brighteat_export_YYYYMMDD_HHMMSS
   ```
   
   The script will:
   - Import the PostgreSQL database
   - Copy media files
   - Import Redis data (if available)
   - Run migrations
   - Collect static files

### Step 4: Update Configuration for New IP

1. **Update `docker-compose.yml` environment variables:**
   ```yaml
   environment:
     - FRONTEND_URL=http://NEW_IP:19991
     - CSRF_TRUSTED_ORIGINS=http://NEW_IP:19991,http://localhost:19991
   ```

2. **Or create/update `.env` file:**
   ```env
   SECRET_KEY=your-secret-key
   DEBUG=False
   DB_NAME=brighteat
   DB_USER=postgres
   DB_PASSWORD=postgres
   DB_HOST=db
   DB_PORT=5432
   FRONTEND_URL=http://NEW_IP:19991
   REDIS_HOST=redis
   REDIS_PORT=6379
   CSRF_TRUSTED_ORIGINS=http://NEW_IP:19991,http://localhost:19991
   CITE_API_BASE_URL=your-cite-api-url
   CELERY_BROKER_URL=redis://redis:6379/0
   CELERY_RESULT_BACKEND=redis://redis:6379/0
   ```

3. **Update frontend API configuration** (if needed):
   - Check `frontend/src/api.js` for any hardcoded URLs
   - Rebuild frontend if necessary:
     ```bash
     cd frontend
     docker compose build frontend
     ```

### Step 5: Restart Services

```bash
# Restart all services
docker compose restart

# Or rebuild and start fresh
docker compose down
docker compose up -d --build
```

### Step 6: Verify Migration

1. **Check database:**
   ```bash
   docker compose exec db psql -U postgres -d brighteat -c "SELECT COUNT(*) FROM orders_user;"
   ```

2. **Check media files:**
   ```bash
   ls -la media/
   ```

3. **Test the application:**
   - Access frontend: `http://NEW_IP:19991`
   - Access backend API: `http://NEW_IP:19992`
   - Test login and basic functionality

## Manual Migration (Alternative Method)

If the scripts don't work, you can migrate manually:

### Manual Database Export/Import

**On source node:**
```bash
# Export database
docker compose exec db pg_dump -U postgres brighteat > brighteat_dump.sql

# Or if using external database
pg_dump -h SOURCE_DB_HOST -U postgres brighteat > brighteat_dump.sql
```

**On destination node:**
```bash
# Import database
docker compose exec -T db psql -U postgres brighteat < brighteat_dump.sql

# Or create database first if it doesn't exist
docker compose exec db psql -U postgres -c "CREATE DATABASE brighteat;"
docker compose exec -T db psql -U postgres brighteat < brighteat_dump.sql
```

### Manual Media Files Transfer

```bash
# On source node - create archive
tar -czf media_backup.tar.gz media/

# Transfer and extract on destination
scp media_backup.tar.gz user@DESTINATION_IP:/path/to/BrightEat/
# On destination
tar -xzf media_backup.tar.gz
```

## Troubleshooting

### Database Import Errors

- **Error: "database does not exist"**
  ```bash
  docker compose exec db psql -U postgres -c "CREATE DATABASE brighteat;"
  ```

- **Error: "permission denied"**
  - Ensure database user has proper permissions
  - Check PostgreSQL user credentials in `docker-compose.yml`

### Media Files Not Accessible

- Check file permissions:
  ```bash
  chmod -R 755 media/
  ```
- Ensure Django can access the media directory
- Check `MEDIA_ROOT` and `MEDIA_URL` in settings.py

### Redis Import Issues

- Redis import is optional - the application will work without it
- If needed, manually copy the dump file:
  ```bash
  docker cp redis_dump.rdb $(docker compose ps -q redis):/data/dump.rdb
  docker compose restart redis
  ```

### Connection Issues After Migration

- Verify firewall rules allow traffic on ports 19991 and 19992
- Check `ALLOWED_HOSTS` in Django settings
- Update CORS settings if frontend is on a different domain
- Verify environment variables are correctly set

## Best Practices

1. **Backup before migration:** Always create a backup before starting migration
2. **Test in staging:** If possible, test the migration process on a staging server first
3. **Maintain downtime window:** Plan for a maintenance window during migration
4. **Verify data integrity:** After migration, verify that all data is present and correct
5. **Update DNS/URLs:** If using domain names, update DNS records to point to the new IP
6. **Monitor logs:** Check application logs after migration for any errors

## Rollback Plan

If something goes wrong, you can rollback:

1. **Stop services on destination:**
   ```bash
   docker compose down
   ```

2. **Restore from backup** (if you created one)

3. **Or re-export from source** and try again

## Additional Notes

- The migration scripts preserve all data including users, orders, menus, and media files
- Redis data (cached sessions, etc.) is optional - the app will regenerate it
- Make sure both nodes have the same codebase version before migration
- Consider migrating during low-traffic periods

## Support

If you encounter issues:
1. Check the export/import script logs
2. Review docker compose  logs: `docker compose logs`
3. Verify database connectivity: `docker compose exec db psql -U postgres -c "\l"`
4. Check file permissions and ownership

