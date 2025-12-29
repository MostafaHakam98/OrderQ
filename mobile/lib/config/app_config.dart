import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Backend server configuration
  // For production server (accessible from internet):
  static const String productionUrl = 'http://51.20.151.57:19992/api';
  
  // For local network (when PWA is accessed from same network):
  static const String localNetworkUrl = 'http://192.168.100.26:19992/api';
  
  // For Android emulator (use 10.0.2.2 to access host machine):
  static const String androidEmulatorUrl = 'http://10.0.2.2:19992/api';
  
  // For iOS simulator (use localhost):
  static const String iosSimulatorUrl = 'http://localhost:19992/api';
  
  // Get the appropriate URL based on platform
  static String get apiBaseUrl {
    // Web platform - use production URL (or local network if on same network)
    if (kIsWeb) {
      // For web/PWA, use production URL
      // If accessing from local network, you can change this to localNetworkUrl
      return productionUrl;
    }
    
    // Mobile platforms - default to production
    // Platform checks are not needed since we already handle web above
    return productionUrl;
  }
  
  // You can manually override by uncommenting one of these:
  // static String get apiBaseUrl => androidEmulatorUrl;  // For Android emulator
  // static String get apiBaseUrl => iosSimulatorUrl;     // For iOS simulator
  // static String get apiBaseUrl => productionUrl;       // For production/physical device
}
