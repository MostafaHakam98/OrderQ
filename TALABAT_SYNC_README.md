# Talabat Menu Sync

This feature automatically syncs menus from Talabat restaurants to your OrderQ database.

## Features

- **Automatic Menu Syncing**: Scrapes menus from Talabat and stores them in the database
- **Diff + Upsert**: Only updates changed items, doesn't rewrite everything
- **Scheduled Syncing**: Uses Celery Beat to sync menus on a schedule
- **Multiple Restaurants**: Sync multiple restaurants from a JSON configuration file

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

This will install:
- `celery` - Task queue
- `django-celery-beat` - Periodic task scheduling
- `redis` - Message broker (or use RabbitMQ)
- `requests` - HTTP library for scraping

### 2. Configure Redis (or RabbitMQ)

Make sure Redis is running:

```bash
# Using Docker
docker run -d -p 6379:6379 redis:alpine

# Or install locally
# On Ubuntu/Debian: sudo apt-get install redis-server
# On macOS: brew install redis
```

Update `settings.py` if needed:
```python
CELERY_BROKER_URL = 'redis://localhost:6379/0'
CELERY_RESULT_BACKEND = 'redis://localhost:6379/0'
```

### 3. Run Migrations

```bash
python manage.py migrate
```

This will add the following fields:
- `Menu.talabat_url` - Talabat URL for the menu
- `Menu.menu_hash` - Hash for change detection
- `Menu.last_synced_at` - Last sync timestamp
- `MenuItem.talabat_id` - Original Talabat item ID
- `MenuItem.item_hash` - Hash for change detection
- `MenuItem.section_name` - Section/category name

### 4. Configure Restaurants to Sync

Edit `restaurants_to_sync.json`:

```json
[
  {
    "name": "Balbaa",
    "url": "https://www.talabat.com/egypt/restaurant/771378/balbaa?aid=7137"
  },
  {
    "name": "Another Restaurant",
    "url": "https://www.talabat.com/egypt/restaurant/XXXXX/restaurant-name?aid=XXXX"
  }
]
```

## Usage

### Manual Sync

Sync all restaurants:
```bash
python manage.py sync_talabat_menus
```

Sync a specific restaurant:
```bash
python manage.py sync_talabat_menus --restaurant "Balbaa"
```

### Scheduled Sync (Celery Beat)

1. Set up the periodic task:
```bash
python manage.py setup_menu_sync_schedule --interval 6
```
This creates a task that runs every 6 hours (adjust as needed).

2. Start Celery Worker:
```bash
celery -A BrightEat worker -l info
```

3. Start Celery Beat (in a separate terminal):
```bash
celery -A BrightEat beat -l info
```

Or use a process manager like supervisor or systemd to run both in the background.

### Docker Setup

If using Docker, add Celery services to `docker-compose.yml`:

```yaml
services:
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"

  celery_worker:
    build:
      context: .
      dockerfile: Dockerfile
    command: celery -A BrightEat worker -l info
    volumes:
      - .:/app
    environment:
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    depends_on:
      - redis
      - db

  celery_beat:
    build:
      context: .
      dockerfile: Dockerfile
    command: celery -A BrightEat beat -l info
    volumes:
      - .:/app
    environment:
      - CELERY_BROKER_URL=redis://redis:6379/0
      - CELERY_RESULT_BACKEND=redis://redis:6379/0
    depends_on:
      - redis
      - db
```

## How It Works

1. **Scraping**: Uses the `talabat_scrap.py` script to fetch menu data from Talabat
2. **Hashing**: Each menu item gets a hash based on its content (name, description, price, etc.)
3. **Diff Detection**: Compares menu hash with stored hash to detect changes
4. **Upsert Logic**:
   - New items: Created in database
   - Changed items: Updated in database
   - Removed items: Marked as unavailable (not deleted)
5. **Scheduling**: Celery Beat runs the sync task periodically

## Troubleshooting

### Import Errors

If you get import errors for `talabat_scrap`, make sure:
- The `scripts/talabat_scrap.py` file exists
- The `requests` library is installed

### Celery Not Running

Check that:
- Redis is running: `redis-cli ping` (should return `PONG`)
- Celery worker is running: Check logs for errors
- Celery Beat is running: Check logs for scheduled tasks

### No Items Found

- Check the Talabat URL is correct
- Check if the restaurant page is accessible
- Check `debug_blocked.html` for blocked/challenge pages

### Database Errors

Make sure migrations are applied:
```bash
python manage.py migrate
```

## API

You can also trigger sync programmatically:

```python
from orders.tasks import sync_talabat_menus_task

# Sync all restaurants
sync_talabat_menus_task.delay()

# Sync specific restaurant
sync_talabat_menus_task.delay(restaurant_name="Balbaa")
```

## Notes

- Items are never deleted, only marked as unavailable when removed from Talabat
- The sync preserves existing items and only updates changed ones
- Menu hash is computed from all item hashes for efficient change detection
- Each restaurant gets one menu per Talabat URL

