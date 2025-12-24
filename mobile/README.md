# BrightEat Mobile App

Flutter mobile application for iOS and Android that connects to the BrightEat Django backend.

## Features

- **Authentication**: Login and user registration (manager only)
- **Order Management**: Create, view, join, lock, unlock, and close orders
- **Order Items**: Add and remove items from orders
- **Restaurant Management**: View and manage restaurants (managers only)
- **Menu Management**: View and manage menus and menu items (managers only)
- **Payments**: Track and mark pending payments
- **Reports**: View monthly spending reports
- **Recommendations**: Add and view recommendations

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- iOS development: Xcode (for iOS builds)
- Android development: Android Studio (for Android builds)

## Setup

1. **Install Flutter dependencies:**
   ```bash
   cd mobile
   flutter pub get
   ```

2. **Configure API Base URL:**
   Edit `lib/services/api_service.dart` and update the `baseUrl` constant:
   ```dart
   static const String baseUrl = 'YOUR_BACKEND_URL/api';
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── user.dart
│   ├── order.dart
│   ├── restaurant.dart
│   ├── menu.dart
│   ├── menu_item.dart
│   ├── order_item.dart
│   └── recommendation.dart
├── services/                 # API services
│   ├── api_service.dart
│   ├── auth_service.dart
│   └── orders_service.dart
├── providers/                # State management
│   ├── auth_provider.dart
│   └── orders_provider.dart
└── screens/                  # UI screens
    ├── login_screen.dart
    ├── register_screen.dart
    ├── home_screen.dart
    ├── orders_screen.dart
    ├── order_detail_screen.dart
    ├── join_order_screen.dart
    ├── restaurants_screen.dart
    ├── menu_management_screen.dart
    ├── profile_screen.dart
    ├── pending_payments_screen.dart
    ├── reports_screen.dart
    └── recommendations_screen.dart
```

## API Endpoints

The app uses the same backend API endpoints as the web application:

- `/api/auth/login/` - User login
- `/api/auth/register/` - User registration
- `/api/orders/` - Order management
- `/api/restaurants/` - Restaurant management
- `/api/menus/` - Menu management
- `/api/menu-items/` - Menu item management
- `/api/order-items/` - Order item management
- `/api/payments/` - Payment management
- `/api/recommendations/` - Recommendations

## Building for Production

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Notes

- The app uses JWT tokens for authentication, stored securely using SharedPreferences
- Token refresh is handled automatically by the API service
- All API calls include proper error handling and loading states
- The UI follows Material Design guidelines

## Troubleshooting

1. **Connection issues**: Ensure the backend URL is correct and the backend server is running
2. **Authentication errors**: Check that tokens are being stored correctly
3. **Build errors**: Run `flutter clean` and `flutter pub get` again

