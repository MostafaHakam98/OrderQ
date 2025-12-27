import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/orders_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/menu_item.dart';
import '../models/user.dart';
import '../services/websocket_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderCode;

  const OrderDetailScreen({Key? key, required this.orderCode}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  WebSocketService? _webSocketService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      _webSocketService = WebSocketService(prefs);
      
      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      await ordersProvider.fetchOrderByCode(widget.orderCode);
      final order = ordersProvider.currentOrder;
      
      if (order != null) {
        if (order.menu != null) {
          ordersProvider.fetchMenuItems(menuId: order.menu!.id);
        }
        
        // Connect to WebSocket for real-time updates
        final oldItemCount = order.items?.length ?? 0;
        _webSocketService!.connect(order.id, (updatedOrder) async {
          print('📥 Received order update via WebSocket');
          
          // Show notification if item was added by someone else
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final currentUserId = authProvider.user?.id;
          
          // Check if new items were added (compare item counts)
          final currentOrder = ordersProvider.currentOrder;
          final previousItemCount = currentOrder?.items?.length ?? oldItemCount;
          
          // Only notify if items were added (not if we're the one who added them)
          final updatedItemCount = updatedOrder.items?.length ?? 0;
          if (updatedItemCount > previousItemCount) {
            // Check if any new items were added by someone else
            final newItems = (updatedOrder.items ?? []).skip(previousItemCount).toList();
            final hasOtherUserItems = newItems.any((item) => 
              item.user != null && item.user!.id != currentUserId
            );
            
            if (hasOtherUserItems || newItems.any((item) => item.user == null && currentUserId != null)) {
              final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
              await notificationsProvider.notifyItemAdded(
                orderCode: updatedOrder.code,
                itemName: newItems.isNotEmpty ? (newItems.first.menuItem?.name ?? newItems.first.customName ?? 'items') : 'items',
                userName: 'Someone',
                orderId: updatedOrder.id.toString(),
              );
            }
          }
          
          // Update the order in provider
          ordersProvider.setCurrentOrder(updatedOrder);
          
          // Refresh the UI
          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _webSocketService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate back instead of exiting
        if (context.canPop()) {
          context.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text('Order ${widget.orderCode}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
                ordersProvider.fetchOrderByCode(widget.orderCode);
              },
              tooltip: 'Refresh',
            ),
          ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final order = ordersProvider.currentOrder;

          if (ordersProvider.isLoading && order == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Order not found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => context.go('/orders'),
                    child: const Text('Go to Orders'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ordersProvider.fetchOrderByCode(widget.orderCode);
              if (order.menu != null) {
                await ordersProvider.fetchMenuItems(menuId: order.menu!.id);
              }
            },
            child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  _buildOrderInfoCard(order, ordersProvider, authProvider),
                const SizedBox(height: 16),
                  if (order.shareMessage != null && order.shareMessage!.isNotEmpty)
                    _buildShareMessageCard(order),
                const SizedBox(height: 16),
                  if (order.status == 'OPEN') _buildAddItemSection(order, ordersProvider),
                  const SizedBox(height: 16),
                  if (order.status != 'OPEN') _buildInstapaySection(order, ordersProvider, authProvider),
                  const SizedBox(height: 16),
                  _buildOrderItemsCard(order, ordersProvider),
                  const SizedBox(height: 16),
                  _buildPaymentsCard(order, ordersProvider, authProvider),
                  const SizedBox(height: 16),
                  _buildOrderActionsCard(order, ordersProvider),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildOrderInfoCard(CollectionOrder order, OrdersProvider ordersProvider, AuthProvider authProvider) {
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
      case 'CLOSED':
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (order.menu != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          order.menu!.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 18, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                    order.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                  ),
                ),
              ],
            ),
                ),
              ],
            ),
            const Divider(height: 32),
            _buildInfoRow(Icons.person, 'Collector', order.collectorName ?? order.collector.username),
            if (order.cutoffTime != null)
              _buildInfoRow(
                Icons.access_time,
                'Cutoff Time',
                order.cutoffTime!.toString().substring(0, 16),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildFeeRow('Delivery Fee', order.deliveryFee, order, ordersProvider, authProvider),
                  _buildFeeRow('Tip', order.tip, order, ordersProvider, authProvider),
                  _buildFeeRow('Service Fee', order.serviceFee, order, ordersProvider, authProvider),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Fee Split',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        order.feeSplitRule.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBreakdownRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          Flexible(
            child: Text(
              '${amount.toStringAsFixed(2)} EGP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, double amount, CollectionOrder order, OrdersProvider ordersProvider, AuthProvider authProvider) {
    final isCollector = order.collector.id == authProvider.user?.id;
    final isManager = authProvider.isManager;
    final canEdit = order.status == 'OPEN' && (isCollector || isManager);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '${amount.toStringAsFixed(2)} EGP',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _showEditFeeDialog(label, amount, order, ordersProvider),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit $label',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showEditFeeDialog(String label, double currentValue, CollectionOrder order, OrdersProvider ordersProvider) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixText: 'EGP',
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = double.tryParse(controller.text);
              if (value == null || value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              final updateData = <String, dynamic>{};
              if (label == 'Delivery Fee') {
                updateData['delivery_fee'] = value;
              } else if (label == 'Tip') {
                updateData['tip'] = value;
              } else if (label == 'Service Fee') {
                updateData['service_fee'] = value;
              }
              
              try {
                await ordersProvider.ordersService.apiService.updateOrder(order.id, updateData);
                
                if (mounted) {
                  Navigator.pop(context);
                  await ordersProvider.fetchOrderByCode(order.code);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fee updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update fee: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemSection(CollectionOrder order, OrdersProvider ordersProvider) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Add Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _showAddMenuItemDialog(order, ordersProvider);
                    },
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('From Menu'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddCustomItemDialog(order, ordersProvider),
                    icon: const Icon(Icons.edit),
                    label: const Text('Custom'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard(CollectionOrder order, OrdersProvider ordersProvider) {
    if (order.items == null || order.items!.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No items yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Group items by user
    final Map<int, List<OrderItem>> itemsByUser = {};
    for (final item in order.items!) {
      if (!itemsByUser.containsKey(item.user.id)) {
        itemsByUser[item.user.id] = [];
      }
      itemsByUser[item.user.id]!.add(item);
    }

    final totalAmount = order.items!.fold<double>(
      0,
      (sum, item) => sum + item.totalPrice,
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue[700]),
                const SizedBox(width: 8),
            const Text(
              'Order Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.items!.length} items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...itemsByUser.entries.map((entry) {
              final user = entry.value.first.user;
              final items = entry.value;
              final subtotal = items.fold<double>(
                0,
                (sum, item) => sum + item.totalPrice,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue[100],
                          child: Text(
                            user.username[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            user.username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Theme.of(context).textTheme.bodyLarge?.color,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${subtotal.toStringAsFixed(2)} EGP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ...items.map((item) => _buildExpandableItemCard(item, order, ordersProvider)),
                  ],
                ),
              );
            }),
            const Divider(height: 32),
            // Fees breakdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildFeeBreakdownRow('Items Subtotal', totalAmount),
                  _buildFeeBreakdownRow('Delivery Fee', order.deliveryFee),
                  _buildFeeBreakdownRow('Tip', order.tip),
                  _buildFeeBreakdownRow('Service Fee', order.serviceFee),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      Text(
                        '${(totalAmount + order.deliveryFee + order.tip + order.serviceFee).toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareMessageCard(CollectionOrder order) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.share, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Share Message',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: SelectableText(
                order.shareMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: order.shareMessage!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Share message copied to clipboard!'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Message'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstapaySection(CollectionOrder order, OrdersProvider ordersProvider, AuthProvider authProvider) {
    final isCollector = order.collector.id == authProvider.user?.id;
    final hasInstapayLink = order.collectorInstapayLink != null && order.collectorInstapayLink!.isNotEmpty;
    final hasQrCode = order.collectorInstapayQrCodeUrl != null && order.collectorInstapayQrCodeUrl!.isNotEmpty;

    if (!hasInstapayLink && !hasQrCode && !isCollector) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'Instapay Payment',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCollector) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditInstapayDialog(order, ordersProvider),
                    tooltip: 'Edit Instapay Link',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (hasQrCode) ...[
              Center(
                child: CachedNetworkImage(
                  imageUrl: order.collectorInstapayQrCodeUrl!,
                  width: 200,
                  height: 200,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (hasInstapayLink) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: order.collectorInstapayLink!,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (hasInstapayLink) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          try {
                            final link = order.collectorInstapayLink!.trim();
                            // Ensure link has protocol
                            String url = link;
                            if (!link.startsWith('http://') && !link.startsWith('https://')) {
                              url = 'https://$link';
                            }
                            
                            final uri = Uri.parse(url);
                            print('🔗 Opening Instapay link: $uri');
                            
                            // Directly launch without checking canLaunchUrl
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            
                            if (!launched && mounted) {
                              // Fallback: try copying to clipboard
                              await Clipboard.setData(ClipboardData(text: link));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link copied to clipboard. Please open it manually.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } catch (e) {
                            print('❌ Error opening link: $e');
                            if (mounted) {
                              // Fallback: copy to clipboard
                              try {
                                await Clipboard.setData(ClipboardData(text: order.collectorInstapayLink!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Link copied to clipboard. Please open it manually.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              } catch (clipboardError) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                    child: Text(
                          order.collectorInstapayLink!,
                      style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () async {
                        try {
                          final link = order.collectorInstapayLink!.trim();
                          // Ensure link has protocol
                          String url = link;
                          if (!link.startsWith('http://') && !link.startsWith('https://')) {
                            url = 'https://$link';
                          }
                          
                          final uri = Uri.parse(url);
                          print('🔗 Opening Instapay link: $uri');
                          
                          // Directly launch without checking canLaunchUrl
                          final launched = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                          
                          if (!launched && mounted) {
                            // Fallback: try copying to clipboard
                            await Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link copied to clipboard. Please open it manually.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        } catch (e) {
                          print('❌ Error opening link: $e');
                          if (mounted) {
                            // Fallback: copy to clipboard
                            try {
                              await Clipboard.setData(ClipboardData(text: order.collectorInstapayLink!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link copied to clipboard. Please open it manually.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } catch (clipboardError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      tooltip: 'Open Link',
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: order.collectorInstapayLink!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Instapay link copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Copy Link',
                    ),
                  ],
                ),
              ),
            ] else if (isCollector) ...[
              Center(
                child: Text(
                  'No Instapay link set. Add one to enable payments.',
                  style: TextStyle(
                    color: Colors.grey[600],
                        fontSize: 14,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditInstapayDialog(CollectionOrder order, OrdersProvider ordersProvider) {
    final controller = TextEditingController(text: order.collectorInstapayLink ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Instapay Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Instapay Link',
            hintText: 'https://ipn.eg/S/...',
            border: OutlineInputBorder(),
            helperText: 'Enter your Instapay payment link',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final link = controller.text.trim();
              if (link.isNotEmpty && !link.startsWith('http')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid URL'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.user != null) {
                  await ordersProvider.ordersService.apiService.updateUser(
                    authProvider.user!.id,
                    {'instapay_link': link},
                  );
                  
                  await ordersProvider.fetchOrderByCode(order.code);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Instapay link updated'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsCard(CollectionOrder order, OrdersProvider ordersProvider, AuthProvider authProvider) {
    if (order.payments == null || order.payments!.isEmpty) {
      return const SizedBox.shrink();
    }

    final isCollector = order.collector.id == authProvider.user?.id;
    final currentUserId = authProvider.user?.id;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  'Payments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...order.payments!.map((payment) {
              final isCurrentUser = payment.user.id == currentUserId;
              final canMarkPaid = !payment.isPaid && 
                  (isCurrentUser || isCollector || authProvider.isManager);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: payment.isPaid 
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.green[900]!.withOpacity(0.3)
                          : Colors.green[50])
                      : Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: payment.isPaid 
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? Colors.green[700]!
                            : Colors.green[200]!)
                        : Colors.orange[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  payment.user.username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(context).textTheme.bodyLarge?.color,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                payment.isPaid ? Icons.check_circle : Icons.pending,
                                size: 18,
                                color: payment.isPaid ? Colors.green : Colors.orange,
                              ),
                            ],
                          ),
                          if (payment.paidAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Paid: ${payment.paidAt!.toString().substring(0, 16)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Flexible(
                      flex: 0,
                      child: Text(
                        '${payment.amount.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: payment.isPaid ? Colors.green[700] : Colors.orange[700],
                        ),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (canMarkPaid) ...[
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final success = await ordersProvider.markPaymentAsPaid(payment.id);
                          if (success && mounted) {
                            // Send notification about payment
                            final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
                            await notificationsProvider.notifyPayment(
                              orderCode: order.code,
                              userName: payment.user.username,
                              amount: payment.amount,
                              isPaid: true,
                              orderId: order.id.toString(),
                            );
                            
                            await ordersProvider.fetchOrderByCode(order.code);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payment marked as paid'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to mark payment as paid'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Mark Paid'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderActionsCard(CollectionOrder order, OrdersProvider ordersProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCollector = order.collector.id == authProvider.user?.id;
    final isManager = authProvider.isManager;

    if (order.status == 'CLOSED') {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order.status == 'OPEN' && (isCollector || isManager)) ...[
              ElevatedButton.icon(
                onPressed: () => _showAssignUsersDialog(order, ordersProvider),
                icon: const Icon(Icons.people),
                label: const Text('Assign Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final success = await ordersProvider.lockOrder(order.id);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order locked'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.lock),
                label: const Text('Lock Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            if (order.status == 'LOCKED' && (isCollector || isManager)) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final success = await ordersProvider.unlockOrder(order.id);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order unlocked'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (isCollector) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await ordersProvider.markOrdered(order.id);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order marked as ordered'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Mark as Ordered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
            if ((order.status == 'ORDERED' || order.status == 'LOCKED') &&
                (isCollector || isManager)) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Close Order'),
                      content: const Text('Are you sure you want to close this order?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                  final success = await ordersProvider.closeOrder(order.id);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order closed'),
                          backgroundColor: Colors.grey,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('Close Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            // Delete order button (only for managers or collectors on open orders)
            if ((isCollector || isManager) && order.status == 'OPEN') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Order'),
                      content: const Text(
                        'Are you sure you want to delete this order? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    final success = await ordersProvider.deleteOrder(order.id);
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order deleted'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      context.go('/orders');
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ordersProvider.lastError ?? 'Failed to delete order'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete),
                label: const Text('Delete Order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMenuItemDialog(CollectionOrder order, OrdersProvider ordersProvider) async {
    // Show loading dialog while fetching
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // Fetch menu items and users - always fetch to ensure we have the latest
    try {
      if (order.menu != null) {
        print('📋 Fetching menu items for menu ID: ${order.menu!.id}');
        await ordersProvider.fetchMenuItems(menuId: order.menu!.id);
        print('📋 After menu fetch: ${ordersProvider.menuItems.length} items');
        
        // If no items found with menu ID, try fetching by restaurant as fallback
        if (ordersProvider.menuItems.isEmpty) {
          print('📋 No items found for menu, trying restaurant fallback...');
          await ordersProvider.fetchMenuItems(restaurantId: order.restaurant.id);
          print('📋 After restaurant fetch: ${ordersProvider.menuItems.length} items');
        }
      } else {
        // If no menu, try fetching by restaurant
        print('📋 No menu found, fetching menu items for restaurant ID: ${order.restaurant.id}');
        await ordersProvider.fetchMenuItems(restaurantId: order.restaurant.id);
        print('📋 After restaurant fetch: ${ordersProvider.menuItems.length} items');
      }
      
      // Fetch users for assignment
      if (ordersProvider.users.isEmpty) {
        await ordersProvider.fetchUsers();
      }
      
      print('📋 Final menu items count: ${ordersProvider.menuItems.length}');
    } catch (e, stackTrace) {
      print('❌ Error fetching menu items: $e');
      print('❌ Stack trace: $stackTrace');
    }
    
    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog
    
    // Get menu items - show all items from provider (they're already filtered by API)
    // Don't filter by menu ID here since API should handle that, but show all if no menu
    List<MenuItem> menuItems;
    if (order.menu != null) {
      // Filter by menu ID
      menuItems = ordersProvider.menuItems
          .where((item) => item.menu == order.menu!.id)
          .toList();
      print('📋 Filtered ${menuItems.length} items matching menu ID ${order.menu!.id}');
      
      // If still empty, show all items as fallback (maybe menu ID mismatch)
      if (menuItems.isEmpty && ordersProvider.menuItems.isNotEmpty) {
        print('⚠️ No items match menu ID, showing all ${ordersProvider.menuItems.length} items as fallback');
        menuItems = ordersProvider.menuItems.toList();
      }
    } else {
      // No menu, show all items
      menuItems = ordersProvider.menuItems.toList();
      print('📋 No menu specified, showing all ${menuItems.length} items');
    }
    
    print('📋 Final filtered menu items: ${menuItems.length}');
    print('📋 Total menu items in provider: ${ordersProvider.menuItems.length}');
    
    MenuItem? selectedItem;
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    int quantity = 1;
    int? selectedUserId; // null means current user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isCollector = order.collector.id == authProvider.user?.id;
    final isManager = authProvider.isManager;
    final canAssignToOthers = isCollector || isManager;

    if (!mounted) return;
    
    // Fetch users if not already loaded
    if (ordersProvider.users.isEmpty) {
      await ordersProvider.fetchUsers();
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Menu Item'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SizedBox(
              width: double.maxFinite,
              child: menuItems.isEmpty
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('No menu items available'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddCustomItemDialog(order, ordersProvider);
                        },
                        child: const Text('Add Custom Item Instead'),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<MenuItem>(
                          decoration: const InputDecoration(
                            labelText: 'Select Menu Item',
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: menuItems.map((item) {
                            return DropdownMenuItem<MenuItem>(
                              value: item,
                              child: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedItem = value),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: quantityController,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            quantity = int.tryParse(value) ?? 1;
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 16),
                        // Notes field
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            border: OutlineInputBorder(),
                            hintText: 'Add a note for this item',
                          ),
                          maxLines: 2,
                        ),
                        if (selectedItem != null) ...[
                          const SizedBox(height: 16),
                          // Searchable user assignment dropdown
                          _buildSearchableUserDropdown(
                            context: context,
                            selectedUserId: selectedUserId,
                            authProvider: authProvider,
                            ordersProvider: ordersProvider,
                            onUserSelected: (userId) => setState(() => selectedUserId = userId),
                          ),
                          const SizedBox(height: 16),
                          // Total display
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.blue[900]!.withOpacity(0.3)
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total:',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '${(selectedItem!.price * quantity).toStringAsFixed(2)} EGP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.blue[300]
                                          : Colors.blue[900],
                                    ),
                                    textAlign: TextAlign.end,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (menuItems.isNotEmpty)
              ElevatedButton(
                onPressed: selectedItem == null
                    ? null
                    : () async {
                        final itemData = <String, dynamic>{
                          'order': order.id,
                          'menu_item': selectedItem!.id,
                          'quantity': quantity,
                          'unit_price': selectedItem!.price,
                          'total_price': selectedItem!.price * quantity,
                        };
                        
                        // Add note if provided
                        if (noteController.text.trim().isNotEmpty) {
                          itemData['note'] = noteController.text.trim();
                        }
                        
                        // Add user assignment if specified
                        if (selectedUserId != null) {
                          itemData['user'] = selectedUserId!;
                        }
                        
                        final success = await ordersProvider.addOrderItem(itemData);

                        if (success && mounted) {
                          // Send notification about item added
                          final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          await notificationsProvider.notifyItemAdded(
                            orderCode: order.code,
                            itemName: selectedItem!.name,
                            userName: authProvider.user?.username ?? 'Someone',
                            orderId: order.id.toString(),
                          );
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Item added successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to add item'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('Add'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddCustomItemDialog(CollectionOrder order, OrdersProvider ordersProvider) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    int? selectedUserId;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Fetch users if needed - await to ensure they're loaded
    if (ordersProvider.users.isEmpty) {
      await ordersProvider.fetchUsers();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Custom Item'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price (EGP)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    // Notes field
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                        hintText: 'Add a note for this item',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // Searchable user assignment dropdown
                    _buildSearchableUserDropdown(
                      context: context,
                      selectedUserId: selectedUserId,
                      authProvider: authProvider,
                      ordersProvider: ordersProvider,
                      onUserSelected: (userId) => setState(() => selectedUserId = userId),
                    ),
                  ],
                ),
              ),
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text) ?? 0.0;
              final quantity = int.tryParse(quantityController.text) ?? 1;

              if (name.isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields correctly'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final itemData = <String, dynamic>{
                'order': order.id,
                'custom_name': name,
                'custom_price': price,
                'quantity': quantity,
                'unit_price': price,
                'total_price': price * quantity,
              };
              
              // Add note if provided
              if (noteController.text.trim().isNotEmpty) {
                itemData['note'] = noteController.text.trim();
              }
              
              // Add user assignment if specified
              if (selectedUserId != null) {
                itemData['user'] = selectedUserId!;
              }

              final success = await ordersProvider.addOrderItem(itemData);

              if (success && mounted) {
                // Send notification about custom item added
                final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await notificationsProvider.notifyItemAdded(
                  orderCode: order.code,
                  itemName: name,
                  userName: authProvider.user?.username ?? 'Someone',
                  orderId: order.id.toString(),
                );
                
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to add item'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _showAssignUsersDialog(CollectionOrder order, OrdersProvider ordersProvider) async {
    Set<int> selectedUserIds = Set.from((order.assignedUsers ?? []).map((u) => u.id));
    
    // Fetch users if needed - await to ensure they're loaded
    if (ordersProvider.users.isEmpty) {
      await ordersProvider.fetchUsers();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Assign Users to Order'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select users for special orders (e.g., birthday cake). Order will be private.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedUserIds = Set.from(ordersProvider.users.map((u) => u.id));
                          });
                        },
                        child: const Text('Select All'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedUserIds.clear();
                          });
                        },
                        child: const Text('Deselect All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...ordersProvider.users.map((user) {
                    final isSelected = selectedUserIds.contains(user.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedUserIds.add(user.id);
                          } else {
                            selectedUserIds.remove(user.id);
                          }
                        });
                      },
                      title: Text(user.username),
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUserIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select at least one user'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  await ordersProvider.ordersService.apiService.updateOrder(
                    order.id,
                    {'assigned_users': selectedUserIds.toList()},
                  );
                  
                  if (mounted) {
                    Navigator.pop(context);
                    await ordersProvider.fetchOrderByCode(order.code);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Assigned users updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update assigned users: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableItemCard(OrderItem item, CollectionOrder order, OrdersProvider ordersProvider) {
    return _ExpandableItemCard(
      item: item,
      order: order,
      ordersProvider: ordersProvider,
    );
  }

  // Searchable user dropdown widget
  Widget _buildSearchableUserDropdown({
    required BuildContext context,
    required int? selectedUserId,
    required AuthProvider authProvider,
    required OrdersProvider ordersProvider,
    required Function(int?) onUserSelected,
  }) {
    // Build list of users with "Me" option first
    // Filter out duplicate users (in case current user is also in the list)
    final currentUserId = authProvider.user?.id;
    final otherUsers = ordersProvider.users.where((u) => u.id != currentUserId).toList();
    
    final allUsers = [
      User(
        id: authProvider.user?.id ?? 0,
        username: authProvider.user?.username ?? 'Me',
        email: authProvider.user?.email ?? '',
        role: 'user',
      ),
      ...otherUsers,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Assign to User',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          isExpanded: true,
          value: selectedUserId,
          items: allUsers.map((user) {
            final isMe = user.id == authProvider.user?.id;
            return DropdownMenuItem<int?>(
              value: isMe ? null : user.id,
              child: Text(
                isMe ? 'Me (${user.username})' : user.username,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) => onUserSelected(value),
        ),
        if (allUsers.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Loading users...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpandableItemCard extends StatefulWidget {
  final OrderItem item;
  final CollectionOrder order;
  final OrdersProvider ordersProvider;

  const _ExpandableItemCard({
    required this.item,
    required this.order,
    required this.ordersProvider,
  });

  @override
  State<_ExpandableItemCard> createState() => _ExpandableItemCardState();
}

class _ExpandableItemCardState extends State<_ExpandableItemCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;
    final isCollector = widget.order.collector.id == currentUserId;
    final isManager = authProvider.isManager;
    final isOwner = widget.item.user.id == currentUserId;
    final canRemove = widget.order.status == 'OPEN' && (isOwner || isCollector || isManager);
    
    // Get item name - check if menuItem exists and has a name
    String itemName = 'Unnamed Item';
    if (widget.item.menuItem != null && widget.item.menuItem!.name.isNotEmpty) {
      itemName = widget.item.menuItem!.name;
    } else if (widget.item.customName != null && widget.item.customName!.isNotEmpty) {
      itemName = widget.item.customName!;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[300]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Collapsed/Header view
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.item.quantity}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Item name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Item name - ensure it's always visible
                        Text(
                          itemName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // "Yours" badge if applicable (only in collapsed view)
                        if (isOwner && widget.order.status == 'OPEN') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue[600],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Yours',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Expand icon only (price shown in expanded view)
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    size: 24,
                  ),
                ],
              ),
            ),
            // Expanded details
            if (_isExpanded) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[700]!
                    : Colors.grey[300]!,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    if (widget.item.menuItem?.description != null &&
                        widget.item.menuItem!.description!.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.item.menuItem!.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Note
                    if (widget.item.note != null && widget.item.note!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.note_outlined,
                              size: 18,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.item.note!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange[900],
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Remove button
                    if (canRemove) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove Item'),
                                content: Text(
                                    'Are you sure you want to remove "$itemName"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Remove', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final success = await widget.ordersProvider.removeOrderItem(widget.item.id);
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Item removed successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to remove item'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          label: const Text('Remove Item', style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
