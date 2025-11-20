# BrightEat

An internal food-ordering portal to replace WhatsApp collections for daily team meals.

## Features

- **Two User Types:**
  - Menu Manager: Adds restaurants, menus, and menu items with prices
  - Normal User: Joins group orders, adds items, and pays via Instapay

- **Collection Orders:**
  - Join by code or link
  - Order states: OPEN → LOCKED → ORDERED → CLOSED
  - Fee splitting (equal, proportional, collector-pays, custom)
  - Full order history and payment tracking
  - Audit logs for all actions

- **Extra Features:**
  - WhatsApp/Teams share messages
  - Monthly reports (spend, collector count, unpaid incidents)
  - Fee presets for quick setup
  - Custom ad-hoc items

## Tech Stack

- **Backend:** Django 5 + DRF + PostgreSQL + JWT auth
- **Frontend:** Vue 3 + Vite + Pinia + TailwindCSS
- **Containerization:** Docker Compose

## Quick Start with Docker

1. **Clone and navigate to the project:**
   ```bash
   cd BrightEat
   ```

2. **Start all services:**
   ```bash
   docker-compose up --build
   ```

3. **Access the application:**
   - Frontend: http://localhost:19991
   - Backend API: http://localhost:19992
   - Admin: http://localhost:19992/admin

## Manual Setup

### Backend Setup

1. **Create virtual environment:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

2. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Set up PostgreSQL database:**
   - Create a database named `brighteat`
   - Update database settings in `BrightEat/settings.py` or use environment variables

4. **Run migrations:**
   ```bash
   python manage.py migrate
   ```

5. **Seed initial data:**
   ```bash
   python manage.py seed_data
   ```

6. **Load menus from JSON configuration (optional):**
   ```bash
   python manage.py load_menus --file menu_config.json
   ```

7. **Create superuser (optional):**
   ```bash
   python manage.py createsuperuser
   ```

8. **Run development server:**
   ```bash
   python manage.py runserver
   ```

### Frontend Setup

1. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Create `.env` file (optional):**
   ```bash
   VITE_API_BASE_URL=http://localhost:19992/api
   ```

4. **Run development server:**
   ```bash
   npm run dev
   ```

5. **Build for production:**
   ```bash
   npm run build
   ```

## Menu Configuration

Menus can be configured via JSON file. See `menu_config.json` for an example format. To load menus from the configuration file:

```bash
python manage.py load_menus --file menu_config.json --manager manager
```

The JSON structure:
```json
{
  "restaurants": [
    {
      "name": "Restaurant Name",
      "description": "Description",
      "menus": [
        {
          "name": "Menu Name",
          "is_active": true,
          "items": [
            {
              "name": "Item Name",
              "description": "Item description",
              "price": 170.00,
              "is_available": true
            }
          ]
        }
      ]
    }
  ]
}
```

## Seed Users

After running `python manage.py seed_data`, you can login with:

- **Manager:**
  - Username: `manager`
  - Password: `manager123`

- **Member:**
  - Username: `mostafa`
  - Password: `mostafa123`

## API Endpoints

### Authentication
- `POST /api/auth/register/` - Register new user
- `POST /api/auth/login/` - Login (get JWT tokens)
- `POST /api/auth/refresh/` - Refresh access token

### Orders
- `GET /api/orders/` - List orders (filter by status)
- `POST /api/orders/` - Create new order
- `GET /api/orders/{id}/` - Get order details
- `GET /api/orders/by_code/?code=ABC123` - Get order by code
- `POST /api/orders/{id}/lock/` - Lock order (collector only)
- `POST /api/orders/{id}/mark_ordered/` - Mark as ordered
- `POST /api/orders/{id}/close/` - Close order
- `GET /api/orders/monthly_report/?user_id=1` - Get monthly report

### Restaurants & Menus
- `GET /api/restaurants/` - List restaurants
- `POST /api/restaurants/` - Create restaurant (manager only)
- `GET /api/menus/?restaurant=1` - List menus
- `GET /api/menu-items/?menu=1` - List menu items

### Order Items
- `POST /api/order-items/` - Add item to order
- `DELETE /api/order-items/{id}/` - Remove item from order

### Payments
- `GET /api/payments/?order=1` - List payments for order
- `POST /api/payments/{id}/mark_paid/` - Mark payment as paid

## Project Structure

```
BrightEat/
├── BrightEat/          # Django project settings
├── orders/              # Main Django app
│   ├── models.py       # Database models
│   ├── serializers.py  # DRF serializers
│   ├── views.py        # API viewsets
│   └── urls.py         # API routes
├── frontend/            # Vue 3 frontend
│   ├── src/
│   │   ├── views/      # Page components
│   │   ├── stores/     # Pinia stores
│   │   └── router/      # Vue Router config
│   └── package.json
├── docker-compose.yml   # Docker Compose config
├── Dockerfile           # Backend Dockerfile
└── requirements.txt     # Python dependencies
```

## Environment Variables

Create a `.env` file in the root directory:

```env
SECRET_KEY=your-secret-key
DEBUG=True
DB_NAME=brighteat
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432
FRONTEND_URL=http://localhost:19991
CITE_API_BASE_URL=https://your-cite-api-url.com
CSRF_TRUSTED_ORIGINS=http://localhost:19991,http://127.0.0.1:19991,http://10.100.70.13:19991
```

**Note:** 
- `CSRF_TRUSTED_ORIGINS` should be a comma-separated list of trusted origins
- `CITE_API_BASE_URL` is the base URL for the cite API service

## Development

### Running Tests

```bash
python manage.py test
```

### Code Formatting

```bash
# Backend
black .
isort .

# Frontend
npm run format
```

## Production Deployment

1. Set `DEBUG=False` in environment variables
2. Set a strong `SECRET_KEY`
3. Configure proper CORS origins
4. Use a production WSGI server (e.g., Gunicorn)
5. Set up proper database backups
6. Configure static file serving (e.g., WhiteNoise or Nginx)

## License

See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

