# Flutter PWA Deployment

This directory contains the Flutter mobile app configured to run as a Progressive Web App (PWA) for iPhone and other mobile devices.

## Quick Start

### Option 1: Build and Deploy with Docker (Recommended)

1. **Build and run with Docker Compose:**
   ```bash
   docker-compose -f docker-compose.pwa.yml up -d --build
   ```

2. **Access the PWA:**
   - Open your browser and navigate to: `http://your-server-ip:19993`
   - On iPhone: Open Safari, navigate to the URL, tap Share → Add to Home Screen

### Option 2: Build Locally

1. **Build the Flutter web app:**
   ```bash
   ./build-pwa.sh
   ```

2. **Test locally:**
   ```bash
   cd build/web
   python3 -m http.server 8080
   ```
   Then open `http://localhost:8080` in your browser

3. **Build Docker image manually:**
   ```bash
   docker build -f Dockerfile.pwa -t orderq-pwa .
   docker run -p 19993:80 orderq-pwa
   ```

## Configuration

### API Endpoint

The app is configured to connect to the backend API. Make sure the backend is accessible from the PWA URL.

The API URL is configured in `lib/config/app_config.dart`. For production, update:
```dart
static const String productionUrl = 'http://your-backend-url:19992/api';
```

### Port Configuration

- **Backend API**: Port `19992`
- **Vue.js Frontend**: Port `19991`
- **Flutter PWA**: Port `19993` (separate deployment)

## Deployment

### Production Deployment

1. **Update API URL** in `lib/config/app_config.dart` to point to your production backend

2. **Build and deploy:**
   ```bash
   docker-compose -f docker-compose.pwa.yml up -d --build
   ```

3. **Configure reverse proxy (optional):**
   If you want to serve the PWA on a domain with HTTPS, configure nginx or another reverse proxy:
   ```nginx
   server {
       listen 443 ssl;
       server_name pwa.yourdomain.com;
       
       location / {
           proxy_pass http://localhost:19993;
       }
   }
   ```

### iPhone Installation

1. Open Safari on iPhone
2. Navigate to the PWA URL
3. Tap the Share button (square with arrow)
4. Select "Add to Home Screen"
5. The app will appear as a standalone app icon

## Features

- ✅ Progressive Web App (PWA) support
- ✅ Offline capability (service worker)
- ✅ Installable on iOS and Android
- ✅ Responsive design for mobile devices
- ✅ WebSocket support for real-time updates
- ✅ Local notifications support

## Troubleshooting

### WebSocket Connection Issues

If WebSocket connections fail, ensure:
1. The backend WebSocket endpoint is accessible
2. The API URL in `app_config.dart` is correct
3. CORS is properly configured on the backend

### Build Issues

If the build fails:
1. Ensure Flutter is installed: `flutter --version`
2. Get dependencies: `flutter pub get`
3. Clean build: `flutter clean && flutter pub get`

### Docker Build Issues

If Docker build fails:
1. Ensure Docker is running
2. Check Dockerfile.pwa for correct paths
3. Verify Flutter base image is accessible

## Notes

- This is a **separate deployment** from the main docker-compose setup
- The PWA runs independently and connects to the same backend API
- Later integration with main docker-compose can be done by adding this service to the main compose file

