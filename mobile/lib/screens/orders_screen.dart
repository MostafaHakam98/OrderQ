import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/orders_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/order.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrdersProvider>(context, listen: false).fetchOrders();
    });
  }

  Widget _buildBottomNavBar() {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 0; // Default to Orders
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Always navigate to home when back is pressed, never exit
        context.go('/');
        return false; // Prevent default back behavior
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Orders',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
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
          PopupMenuButton<String>(
            onSelected: (status) {
              setState(() {
                _selectedStatus = status == 'All' ? null : status;
              });
              Provider.of<OrdersProvider>(context, listen: false)
                  .fetchOrders(status: _selectedStatus);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'OPEN', child: Text('Open')),
              const PopupMenuItem(value: 'LOCKED', child: Text('Locked')),
              const PopupMenuItem(value: 'ORDERED', child: Text('Ordered')),
              const PopupMenuItem(value: 'CLOSED', child: Text('Closed')),
            ],
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/orders/create'),
        child: const Icon(Icons.add),
        tooltip: 'Create New Order',
      ),
      body: _SwipeableScreen(
        onSwipeLeft: () {
          // Swipe left = go to wheel
          context.go('/wheel');
        },
        onSwipeRight: () {
          // Swipe right = go back to home
          context.go('/');
        },
        child: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = ordersProvider.orders;

          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ordersProvider.fetchOrders(status: _selectedStatus),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No orders found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a new order or join an existing one',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/orders/create'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Order'),
                        ),
                        if (ordersProvider.lastError != null) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              ordersProvider.lastError!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ordersProvider.fetchOrders(status: _selectedStatus),
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderCard(order);
              },
            ),
          );
        },
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildOrderCard(CollectionOrder order) {
    Color statusColor;
    switch (order.status) {
      case 'OPEN':
        statusColor = Colors.green;
        break;
      case 'LOCKED':
        statusColor = Colors.orange;
        break;
      case 'ORDERED':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          order.restaurantName ?? order.restaurant.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code: ${order.code}'),
            Text('Collector: ${order.collectorName ?? order.collector.username}'),
            Row(
              children: [
                const Text('Status: '),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Text('Created: ${order.createdAt.toString().substring(0, 16)}'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => context.push('/orders/${order.code}'),
        ),
        isThreeLine: true,
      ),
    );
  }
}

// Swipeable screen widget for navigation with smooth transitions
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

