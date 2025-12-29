import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    
    _animationController.forward();
    
    // Check if user is already authenticated (auto-login from token)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // Ensure initialization is complete (in case it hasn't finished yet)
      if (!authProvider.isAuthenticated && !authProvider.isLoading) {
        await authProvider.initialize();
      }
      // If user is authenticated, redirect to home (bypass login)
      if (authProvider.isAuthenticated && mounted) {
        context.go('/splash-transition');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username');
    final rememberMe = prefs.getBool('remember_me') ?? false;
    
    if (rememberMe && savedUsername != null) {
      setState(() {
        _usernameController.text = savedUsername;
        _rememberMe = true;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      
      final success = await authProvider.login(username, password);

      if (success && mounted) {
        // Save credentials if remember me is checked
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_username', username);
          await prefs.setBool('remember_me', true);
        } else {
          await prefs.remove('saved_username');
          await prefs.remove('remember_me');
        }
        
        // Connect to notifications WebSocket after successful login
        final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
        notificationsProvider.connectWebSocket(context);
        
        context.go('/splash-transition');
      } else if (mounted) {
        final errorMessage = authProvider.lastError ?? 'Login failed. Please check your credentials.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0A1A3A), // Very dark blue
                    const Color(0xFF0D1F47), // Dark blue
                    const Color(0xFF102354), // Slightly lighter dark blue
                  ]
                : [
                    Colors.blue[50]!,
                    Colors.blue[100]!,
                    Colors.white,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 40),
                            // Animated Logo
                            ScaleTransition(
                              scale: _logoAnimation,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]!.withOpacity(0.8)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.5)
                                          : Colors.black.withOpacity(0.1),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 100,
                                  height: 100,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Welcome Text
                            Text(
                              'Welcome Back!',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.blue[900],
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue to OrderQ',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.blue[200] : Colors.blue[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 48),
                            // Form Card
                            Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Username Field
                                    Focus(
                                      onFocusChange: (hasFocus) {
                                        setState(() {});
                                      },
                                      child: TextFormField(
                                        controller: _usernameController,
                                        focusNode: _usernameFocusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Username or Email',
                                          labelStyle: TextStyle(
                                            color: _usernameFocusNode.hasFocus
                                                ? Colors.blue
                                                : isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: isDark
                                              ? Colors.grey[800]!.withOpacity(0.5)
                                              : Colors.grey[50],
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          isDense: false,
                                          prefixIcon: Icon(
                                            Icons.person_outline,
                                            color: _usernameFocusNode.hasFocus
                                                ? Colors.blue
                                                : isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        keyboardType: TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) {
                                          FocusScope.of(context)
                                              .requestFocus(_passwordFocusNode);
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your username or email';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    // Password Field
                                    Focus(
                                      onFocusChange: (hasFocus) {
                                        setState(() {});
                                      },
                                      child: TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          labelStyle: TextStyle(
                                            color: _passwordFocusNode.hasFocus
                                                ? Colors.blue
                                                : isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? Colors.grey[700]!
                                                  : Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: isDark
                                              ? Colors.grey[800]!.withOpacity(0.5)
                                              : Colors.grey[50],
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                          isDense: false,
                                          prefixIcon: Icon(
                                            Icons.lock_outline,
                                            color: _passwordFocusNode.hasFocus
                                                ? Colors.blue
                                                : isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey[600],
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _handleLogin(),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Remember Me
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                          activeColor: Colors.blue,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const Text(
                                          'Remember me',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    // Login Button
                                    Consumer<AuthProvider>(
                                      builder: (context, authProvider, _) {
                                        return Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                            gradient: LinearGradient(
                                              colors: isDark
                                                  ? [
                                                      Colors.blue[800]!,
                                                      Colors.blue[900]!,
                                                    ]
                                                  : [
                                                      Colors.blue[600]!,
                                                      Colors.blue[700]!,
                                                    ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(isDark ? 0.5 : 0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : _handleLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: authProvider.isLoading
                                                ? const SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        'Sign In',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons.arrow_forward,
                                                        color: Colors.white,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Footer Text
                            Text(
                              'Contact your manager to create an account',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.blue[200] : Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

