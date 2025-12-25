import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/order.dart';
import '../models/restaurant.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      ordersProvider.fetchRestaurants();
      ordersProvider.fetchOrders();
      ordersProvider.fetchPendingPayments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // Show exit confirmation dialog
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit OrderQ?'),
              content: const Text('Are you sure you want to exit the application?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Exit', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (shouldExit == true) {
            // Exit the app
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text(
              'OrderQ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, notificationsProvider, _) {
              final unreadCount = notificationsProvider.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => context.push('/notifications'),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _SwipeableScreen(
        onSwipeLeft: () {
          // Swipe left = go to orders
          context.go('/orders');
        },
        child: RefreshIndicator(
        onRefresh: () async {
          final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
          await Future.wait([
            ordersProvider.fetchRestaurants(),
            ordersProvider.fetchOrders(),
            ordersProvider.fetchPendingPayments(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
              _buildWelcomeSection(),
              _buildQuickActions(),
            _buildActiveOrdersSection(),
          ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[400]!,
            Colors.blue[600]!,
          ],
        ),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 80,
            height: 80,
          ),
          const SizedBox(height: 16),
          const Text(
            'Welcome to OrderQ',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your internal food ordering portal',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            ),
            const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'Create Order',
                  color: Colors.blue,
                  onTap: () => _showRestaurantSelection(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Join Order',
                  color: Colors.green,
                  onTap: () => _showJoinOrderDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  icon: Icons.receipt_long,
                  title: 'All Orders',
                  color: Colors.orange,
                  onTap: () => context.push('/orders'),
                  ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  icon: Icons.payment,
                  title: 'Payments',
                  color: Colors.purple,
                  onTap: () => context.push('/pending-payments'),
                ),
              ),
            ],
          ),
        ],
      ),
                    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Helper to get a darker shade of the color
    Color getDarkerColor(Color c) {
      return Color.fromRGBO(
        (c.red * 0.7).round().clamp(0, 255),
        (c.green * 0.7).round().clamp(0, 255),
        (c.blue * 0.7).round().clamp(0, 255),
        1.0,
                );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: getDarkerColor(color),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showRestaurantSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.restaurants.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text(
                        'Select Restaurant',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: ordersProvider.restaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = ordersProvider.restaurants[index];
                      return _buildRestaurantCard(restaurant, ordersProvider);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, OrdersProvider ordersProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.restaurant,
            color: Colors.blue[700],
            size: 28,
          ),
        ),
        title: Text(
          restaurant.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[600]),
        onTap: () {
          Navigator.pop(context);
          context.push('/orders/create?restaurant=${restaurant.id}');
        },
      ),
    );
  }

  void _showJoinOrderDialog(BuildContext context) {
    final joinCodeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Join Order'),
        content: TextField(
              controller: joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Order Code',
                border: OutlineInputBorder(),
                hintText: 'Enter order code',
            prefixIcon: Icon(Icons.qr_code),
              ),
              textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
            ElevatedButton(
              onPressed: () {
                final code = joinCodeController.text.trim().toUpperCase();
                if (code.isNotEmpty) {
                Navigator.pop(context);
                  context.push('/orders/$code');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            child: const Text('Join'),
            ),
          ],
      ),
    );
  }

  Widget _buildActiveOrdersSection() {
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, _) {
        if (ordersProvider.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final activeOrders = ordersProvider.activeOrders;

        if (activeOrders.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No active orders',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new order to get started',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
          children: [
            const Text(
              'Active Orders',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/orders'),
                    child: const Text('View All'),
                  ),
                ],
            ),
              const SizedBox(height: 12),
              ...activeOrders.take(3).map((order) => _buildOrderCard(order, ordersProvider)),
          ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(CollectionOrder order, OrdersProvider ordersProvider) {
    final pendingPayment = ordersProvider.pendingPayments.firstWhere(
      (p) => p['order_id'] == order.id,
      orElse: () => {},
    );

    Color statusColor;
    IconData statusIcon;
    switch (order.status) {
      case 'OPEN':
        statusColor = Colors.green;
        statusIcon = Icons.lock_open;
        break;
      case 'LOCKED':
        statusColor = Colors.orange;
        statusIcon = Icons.lock;
        break;
      case 'ORDERED':
        statusColor = Colors.blue;
        statusIcon = Icons.shopping_cart;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/orders/${order.code}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.restaurantName ?? order.restaurant.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Code: ${order.code}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                    order.status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                  ),
                ),
              ],
            ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    order.collectorName ?? order.collector.username,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (pendingPayment.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment, size: 14, color: Colors.orange[900]),
                          const SizedBox(width: 4),
              Text(
                            '${pendingPayment['amount']?.toStringAsFixed(2) ?? '0.00'} EGP',
                            style: TextStyle(
                              color: Colors.orange[900],
                  fontWeight: FontWeight.bold,
                              fontSize: 12,
                ),
              ),
          ],
        ),
                    ),
                  ],
                ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    // Get current route to determine active index
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 2; // Default to Home (middle)
    if (location == '/') {
      currentIndex = 2; // Home is in the middle
    } else if (location == '/orders' || location.startsWith('/orders/')) {
      currentIndex = 0;
    } else if (location == '/wheel') {
      currentIndex = 1;
    } else if (location == '/restaurants' || location.startsWith('/restaurants/')) {
      currentIndex = 3;
    } else if (location == '/profile') {
      currentIndex = 4;
    }

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.casino),
          label: 'Wheel',
        ),
        BottomNavigationBarItem(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.home,
              size: 32,
              color: Colors.white,
            ),
          ),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant),
          label: 'Restaurants',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/orders');
            break;
          case 1:
            context.go('/wheel');
            break;
          case 2:
            context.go('/');
            break;
          case 3:
            context.go('/restaurants');
            break;
          case 4:
            context.go('/profile');
            break;
        }
      },
    );
  }
}

// Swipeable screen widget for navigation
class _SwipeableScreen extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const _SwipeableScreen({
    Key? key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 500 && onSwipeRight != null) {
            // Swipe right - go to previous screen
            onSwipeRight!();
          } else if (details.primaryVelocity! < -500 && onSwipeLeft != null) {
            // Swipe left - go to next screen
            onSwipeLeft!();
          }
        }
      },
      child: child,
    );
  }
}
