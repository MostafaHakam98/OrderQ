# BrightEat Mobile App - Setup Guide

## Overview

This Flutter mobile application provides the same functionality as the web application, connecting to the same Django backend API. It supports both iOS and Android platforms.

## Quick Start

1. **Install Flutter** (if not already installed):
   ```bash
   # Check Flutter installation
   flutter doctor
   ```

2. **Navigate to the mobile directory:**
   ```bash
   cd mobile
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Configure API URL:**
   - Open `lib/config/app_config.dart`
   - Update the `apiBaseUrl` constant with your backend URL
   - For Android emulator: use `http://10.0.2.2:19992/api`
   - For iOS simulator: use `http://localhost:19992/api`
   - For physical devices: use your computer's IP address (e.g., `http://10.100.70.13:19992/api`)

5. **Run the app:**
   ```bash
   flutter run
   ```

## Features Implemented

### Authentication
- ✅ Login with username/email and password
- ✅ User registration (manager only)
- ✅ JWT token management with automatic refresh
- ✅ Secure token storage

### Order Management
- ✅ Create new orders
- ✅ View all orders with filtering
- ✅ Join orders by code
- ✅ View order details
- ✅ Lock/unlock orders
- ✅ Mark orders as ordered
- ✅ Close orders
- ✅ Delete orders

### Order Items
- ✅ Add items to orders
- ✅ Remove items from orders
- ✅ View items grouped by user
- ✅ Support for custom items and menu items

### Restaurant & Menu Management (Managers)
- ✅ View restaurants
- ✅ Create restaurants
- ✅ View menus
- ✅ View menu items

### Payments
- ✅ View pending payments
- ✅ Mark payments as paid

### Reports
- ✅ Monthly spending reports
- ✅ Collector statistics
- ✅ Unpaid incidents tracking

### Profile
- ✅ View user profile
- ✅ Access to all features from profile

## Project Structure

```
mobile/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   └── app_config.dart         # API configuration
│   ├── models/                      # Data models
│   │   ├── user.dart
│   │   ├── order.dart
│   │   ├── restaurant.dart
│   │   ├── menu.dart
│   │   ├── menu_item.dart
│   │   ├── order_item.dart
│   │   └── recommendation.dart
│   ├── services/                    # API services
│   │   ├── api_service.dart        # HTTP client with auth
│   │   ├── auth_service.dart       # Authentication service
│   │   └── orders_service.dart     # Orders & related services
│   ├── providers/                   # State management
│   │   ├── auth_provider.dart      # Auth state
│   │   └── orders_provider.dart    # Orders state
│   └── screens/                     # UI screens
│       ├── login_screen.dart
│       ├── register_screen.dart
│       ├── home_screen.dart
│       ├── orders_screen.dart
│       ├── order_detail_screen.dart
│       ├── join_order_screen.dart
│       ├── restaurants_screen.dart
│       ├── menu_management_screen.dart
│       ├── profile_screen.dart
│       ├── pending_payments_screen.dart
│       ├── reports_screen.dart
│       └── recommendations_screen.dart
├── pubspec.yaml                     # Dependencies
└── README.md                        # Documentation
```

## API Endpoints Used

All endpoints match the web application:

- `POST /api/auth/login/` - User login
- `POST /api/auth/register/` - User registration
- `POST /api/auth/refresh/` - Token refresh
- `GET /api/users/me/` - Current user
- `GET /api/orders/` - List orders
- `GET /api/orders/by_code/` - Get order by code
- `POST /api/orders/` - Create order
- `POST /api/orders/{id}/lock/` - Lock order
- `POST /api/orders/{id}/unlock/` - Unlock order
- `POST /api/orders/{id}/mark_ordered/` - Mark as ordered
- `POST /api/orders/{id}/close/` - Close order
- `GET /api/orders/pending_payments/` - Pending payments
- `GET /api/orders/monthly_report/` - Monthly report
- `GET /api/restaurants/` - List restaurants
- `POST /api/restaurants/` - Create restaurant
- `GET /api/menus/` - List menus
- `GET /api/menu-items/` - List menu items
- `POST /api/order-items/` - Add order item
- `DELETE /api/order-items/{id}/` - Remove order item
- `POST /api/payments/{id}/mark_paid/` - Mark payment as paid
- `GET /api/recommendations/` - List recommendations
- `POST /api/recommendations/` - Create recommendation

## Building for Production

### Android APK
```bash
flutter build apk --release
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Connection Issues
- Ensure backend server is running
- Check API URL in `lib/config/app_config.dart`
- For physical devices, ensure phone and computer are on same network
- Check firewall settings

### Authentication Issues
- Verify tokens are being stored (check SharedPreferences)
- Check backend CORS settings
- Ensure JWT settings match backend

### Build Errors
```bash
flutter clean
flutter pub get
flutter run
```

## Next Steps

1. Customize the UI theme in `main.dart`
2. Add more error handling as needed
3. Implement push notifications (optional)
4. Add offline support (optional)
5. Customize app icons and splash screens

## Notes

- The app uses Provider for state management
- All API calls include proper error handling
- Token refresh is handled automatically
- The UI follows Material Design guidelines
- All screens are responsive and work on both iOS and Android

