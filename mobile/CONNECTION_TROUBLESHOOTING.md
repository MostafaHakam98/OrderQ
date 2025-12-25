# Connection Troubleshooting Guide

If you're getting "Cannot connect to server" error, follow these steps:

## Quick Fixes

### 1. Check What Device You're Using

**Android Emulator:**
- The emulator can't directly access `51.20.151.57`
- You need to use `10.0.2.2` which maps to your host machine's localhost
- **BUT** if your backend is on a remote server (not localhost), the emulator needs internet access to reach it

**Physical Android Device:**
- Must be on the same network as the server, OR
- The server must be publicly accessible from the internet
- Check if your phone can reach `http://51.20.151.57:19992` in a browser

**iOS Simulator:**
- Can use `localhost` if backend is on your Mac
- For remote server, use the actual IP like Android

### 2. Test Server Accessibility

**From your laptop (should work):**
```bash
curl http://51.20.151.57:19992/api/orders/
```

**From your phone's browser:**
- Open browser on your phone
- Go to: `http://51.20.151.57:19992/api/orders/`
- You should see a JSON response or error (not "connection refused")

### 3. For Android Emulator - Use Special IP

If you're testing on Android emulator and the backend is on your **local machine** (localhost):

1. Edit `mobile/lib/config/app_config.dart`
2. Change line to use emulator URL:
   ```dart
   static String get apiBaseUrl => androidEmulatorUrl;  // Uncomment this
   ```

3. Rebuild the app:
   ```bash
   flutter clean
   flutter run
   ```

### 4. For Physical Device - Check Network

**If server is on your local network:**
1. Find your laptop's local IP:
   ```bash
   hostname -I | awk '{print $1}'
   ```
2. Update `app_config.dart` to use that IP instead of `51.20.151.57`
3. Make sure phone and laptop are on the same WiFi network

**If server is remote (51.20.151.57):**
1. Make sure your phone has internet access
2. Test in phone browser: `http://51.20.151.57:19992/api/orders/`
3. If browser can't connect, the phone can't reach the server (firewall/network issue)

### 5. Check Android Network Security

The app now includes network security config to allow HTTP connections. If you still have issues:

1. Make sure `android/app/src/main/res/xml/network_security_config.xml` exists
2. Make sure `AndroidManifest.xml` references it
3. Rebuild the app completely:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 6. Debug Information

The app now prints the API URL it's using. Check the console/logcat:
```
🔗 API Base URL: http://51.20.151.57:19992/api
```

If you see a different URL, that's what the app is trying to connect to.

## Common Issues

### Issue: "Connection timeout"
- Server might be down
- Firewall blocking port 19992
- Network connectivity issues

### Issue: "Connection refused"
- Server not running
- Wrong IP address
- Wrong port number

### Issue: Works on laptop but not phone
- Phone and laptop on different networks
- Server only listening on localhost (127.0.0.1) instead of 0.0.0.0
- Firewall blocking external connections

### Issue: Works on browser but not app
- Android network security config issue (should be fixed now)
- App using wrong URL (check debug output)

## Testing Steps

1. **Test from laptop:**
   ```bash
   curl http://51.20.151.57:19992/api/orders/
   ```

2. **Test from phone browser:**
   - Open `http://51.20.151.57:19992/api/orders/`
   - Should see JSON or error (not connection refused)

3. **Check app logs:**
   ```bash
   flutter run
   # Look for: 🔗 API Base URL: ...
   ```

4. **If using emulator, test connectivity:**
   ```bash
   # From emulator, test if it can reach the server
   adb shell
   curl http://51.20.151.57:19992/api/orders/
   ```

## Current Configuration

- **Production URL**: `http://51.20.151.57:19992/api`
- **Android Emulator URL**: `http://10.0.2.2:19992/api` (for localhost backend)
- **iOS Simulator URL**: `http://localhost:19992/api` (for localhost backend)

The app currently uses the production URL. If you need to switch, edit `mobile/lib/config/app_config.dart`.

