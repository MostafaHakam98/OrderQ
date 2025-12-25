import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  User? _user;
  bool _isLoading = false;

  AuthProvider(this.authService);

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isManager => _user?.role == 'manager';
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    if (authService.isAuthenticated) {
      _isLoading = true;
      notifyListeners();
      try {
        await fetchUser();
      } catch (e) {
        // If token is invalid/expired, clear it
        _user = null;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await authService.login(usernameOrEmail, password);
    
    if (result['success'] == true) {
      await fetchUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      _lastError = result['error'] ?? 'Login failed';
      return false;
    }
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> register(Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();

    final result = await authService.register(userData);
    
    _isLoading = false;
    notifyListeners();
    return result['success'] == true;
  }

  Future<void> fetchUser() async {
    try {
      _user = await authService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      // If fetching user fails (e.g., token expired, network error), clear user
      // Only log if it's not a connection error (those are logged in API service)
      if (e.toString().contains('connection') || e.toString().contains('SocketException')) {
        // Connection errors are expected and already logged, just clear user silently
      } else {
        print('⚠️ Failed to fetch user: $e');
      }
      _user = null;
      notifyListeners();
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return false;

    _isLoading = true;
    notifyListeners();

    final result = await authService.updateProfile(_user!.id, data);
    
    if (result['success'] == true && result['data'] != null) {
      _user = result['data'];
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(
    String oldPassword,
    String newPassword,
    String newPasswordConfirm,
  ) async {
    _isLoading = true;
    notifyListeners();

    final result = await authService.changePassword(
      oldPassword,
      newPassword,
      newPasswordConfirm,
    );
    
    _isLoading = false;
    notifyListeners();
    return result['success'] == true;
  }

  Future<void> logout() async {
    await authService.logout();
    _user = null;
    notifyListeners();
  }
}

