# Quick Migration Reference

## Export from Source Node

```bash
cd /path/to/BrightEat
chmod +x scripts/export_data.sh
./scripts/export_data.sh
```

This creates: `brighteat_export_YYYYMMDD_HHMMSS/` or `.tar.gz`

## Transfer to Destination Node

```bash
# Using SCP
scp -r brighteat_export_* user@DESTINATION_IP:/path/to/BrightEat/

# Or using RSYNC (better for large files)
rsync -avz --progress brighteat_export_* user@DESTINATION_IP:/path/to/BrightEat/
```

## Import on Destination Node

```bash
cd /path/to/BrightEat
chmod +x scripts/import_data.sh
./scripts/import_data.sh brighteat_export_YYYYMMDD_HHMMSS
```

## Update Configuration

1. Update `docker-compose.yml` or `.env` with new IP:
   - `FRONTEND_URL=http://NEW_IP:19991`
   - `CSRF_TRUSTED_ORIGINS=http://NEW_IP:19991,...`

2. Restart services:
   ```bash
   docker compose restart
   ```

## Verify

```bash
# Check database
docker compose exec db psql -U postgres -d brighteat -c "SELECT COUNT(*) FROM orders_user;"

# Test application
curl http://NEW_IP:19991
```

For detailed instructions, see: `docs/MIGRATION_GUIDE.md`

