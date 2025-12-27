import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/orders_service.dart';
import 'providers/auth_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/join_order_screen.dart';
import 'screens/create_order_screen.dart';
import 'screens/restaurants_screen.dart';
import 'screens/menu_management_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/pending_payments_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/restaurant_wheel_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/user_management_screen.dart';
import 'screens/splash_screen.dart';
import 'providers/notifications_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize shared preferences
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Initialize API service
  final apiService = ApiService(prefs);
  
  // Initialize services
  final authService = AuthService(apiService, prefs);
  final ordersService = OrdersService(apiService);
  
  // Check if user has a valid token (they will be auto-logged in by AuthProvider.initialize())
  final token = prefs.getString('access_token');
  final hasToken = token != null && token.isNotEmpty;
  
  runApp(MyApp(
    authService: authService,
    ordersService: ordersService,
    isAuthenticated: hasToken,
  ));
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  final OrdersService ordersService;
  final bool isAuthenticated;

  const MyApp({
    Key? key,
    required this.authService,
    required this.ordersService,
    required this.isAuthenticated,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = _createRouter(widget.isAuthenticated);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AuthProvider(widget.authService);
            // Initialize immediately to fetch user if token exists
            // This will auto-login the user if they have a valid token
            provider.initialize();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => OrdersProvider(widget.ordersService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationsProvider(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: 'OrderQ',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              brightness: Brightness.dark,
            ),
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }

  GoRouter _createRouter(bool isAuthenticated) {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RegisterScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/splash-transition',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SplashScreen(
              duration: Duration(seconds: 1),
              isTransition: true,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const OrdersScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/orders/create',
          pageBuilder: (context, state) {
            // Extract restaurant ID from query parameters if present
            final restaurantId = state.uri.queryParameters['restaurant'];
            return CustomTransitionPage(
              key: state.pageKey,
              child: CreateOrderScreen(initialRestaurantId: restaurantId != null ? int.tryParse(restaurantId) : null),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
          },
        ),
        GoRoute(
          path: '/orders/:code',
          pageBuilder: (context, state) {
            final code = state.pathParameters['code'] ?? '';
            return CustomTransitionPage(
              key: state.pageKey,
              child: OrderDetailScreen(orderCode: code.toUpperCase()),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
          },
        ),
        GoRoute(
          path: '/join/:code',
          pageBuilder: (context, state) {
            final code = state.pathParameters['code'] ?? '';
            return CustomTransitionPage(
              key: state.pageKey,
              child: JoinOrderScreen(orderCode: code.toUpperCase()),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
          },
        ),
        GoRoute(
          path: '/restaurants',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RestaurantsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/wheel',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RestaurantWheelScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/restaurants/:restaurantId/menus',
          pageBuilder: (context, state) {
            final restaurantId = int.parse(state.pathParameters['restaurantId'] ?? '0');
            return CustomTransitionPage(
              key: state.pageKey,
              child: MenuManagementScreen(restaurantId: restaurantId),
              transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            );
          },
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ReportsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/pending-payments',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const PendingPaymentsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/recommendations',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const RecommendationsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/notifications',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const NotificationsScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        GoRoute(
          path: '/users',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const UserManagementScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
      ],
      redirect: (context, state) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final isAuth = authProvider.isAuthenticated;
        final isManager = authProvider.isManager;
        final isAdmin = authProvider.isAdmin;
        final isSplashRoute = state.uri.path == '/splash';
        final isSplashTransitionRoute = state.uri.path == '/splash-transition';
        final isLoginRoute = state.uri.path == '/login';
        final isRegisterRoute = state.uri.path == '/register';
        final isUsersRoute = state.uri.path == '/users';
        final requiresAuth = !isLoginRoute && !isRegisterRoute && !isSplashRoute && !isSplashTransitionRoute;
        final requiresManager = state.uri.path.startsWith('/restaurants');
        final requiresAdmin = isRegisterRoute || isUsersRoute;

        // Allow splash screens to stay (they handle their own navigation)
        if (isSplashRoute || isSplashTransitionRoute) {
          return null;
        }

        if (requiresAuth && !isAuth) {
          return '/login';
        }
        if (isAuth && isLoginRoute) {
          return '/splash-transition';
        }
        if (isAuth && isRegisterRoute && !isAdmin) {
          return '/';
        }
        if (isAuth && isUsersRoute && !isAdmin) {
          return '/';
        }
        if (requiresManager && !isManager && !isAdmin) {
          return '/';
        }
        if (requiresAdmin && !isAdmin) {
          return '/';
        }
        
        return null;
      },
    );
  }
}

