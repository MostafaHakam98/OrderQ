import '../models/order.dart';
import '../models/restaurant.dart';
import '../models/menu.dart';
import '../models/menu_item.dart';
import '../models/order_item.dart';
import '../models/recommendation.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';

class OrdersService {
  final ApiService apiService;
  
  OrdersService(this.apiService);

  Future<List<CollectionOrder>> fetchOrders({String? status}) async {
    try {
      final response = await apiService.getOrders(status: status);
      final data = response.data;
      final results = data['results'] ?? data;
      if (results is List) {
        final orders = <CollectionOrder>[];
        
        // Collect all menu IDs and menu item IDs from all orders
        Map<int, Set<int>> menuToMenuItemIds = {};
        for (var i = 0; i < results.length; i++) {
          try {
            final json = results[i];
            if (json is Map) {
              final orderData = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json);
              
              // Extract menu ID
              int? menuId;
              if (orderData['menu'] != null) {
                if (orderData['menu'] is Map) {
                  menuId = orderData['menu']['id'];
                } else if (orderData['menu'] is int) {
                  menuId = orderData['menu'];
                }
              }
              
              // Extract menu item IDs from order items
              if (menuId != null && orderData['items'] != null && orderData['items'] is List) {
                final items = orderData['items'] as List;
                for (var item in items) {
                  if (item is Map && item['menu_item'] != null && item['menu_item'] is int) {
                    menuToMenuItemIds.putIfAbsent(menuId, () => <int>{}).add(item['menu_item'] as int);
                  }
                }
              }
            }
          } catch (e) {
            // Continue processing other orders
          }
        }
        
        // Fetch menu items for all menus
        Map<int, MenuItem> allMenuItems = {};
        for (var menuId in menuToMenuItemIds.keys) {
          try {
            final menuItems = await fetchMenuItems(menuId: menuId);
            for (var item in menuItems) {
              allMenuItems[item.id] = item;
            }
          } catch (e) {
            print('⚠️ Could not fetch menu items for menu $menuId: $e');
          }
        }
        
        // Parse orders and enhance with menu item names
        for (var i = 0; i < results.length; i++) {
          try {
            final json = results[i];
            if (json is Map) {
              final orderData = json is Map<String, dynamic> ? json : Map<String, dynamic>.from(json);
              
              // Enhance order items with menu item names
              if (orderData['items'] != null && orderData['items'] is List) {
                final items = orderData['items'] as List;
                for (var item in items) {
                  if (item is Map && item['menu_item'] != null && item['menu_item'] is int) {
                    final menuItemId = item['menu_item'] as int;
                    final menuItem = allMenuItems[menuItemId];
                    if (menuItem != null) {
                      item['menu_item_name'] = menuItem.name;
                      item['menu_item_menu'] = menuItem.menu;
                    }
                  }
                }
              }
              
              orders.add(CollectionOrder.fromJson(orderData));
            } else {
              print('⚠️ Warning: Order at index $i is not a Map. Type: ${json.runtimeType}, Value: $json');
            }
          } catch (e, stackTrace) {
            print('❌ Error parsing order at index $i: $e');
            print('❌ Order data: ${results[i]}');
            print('❌ Stack trace: $stackTrace');
            // Continue with other orders instead of failing completely
          }
        }
        return orders;
      }
      print('⚠️ Warning: Orders response is not a list. Data: $data');
      return [];
    } catch (e, stackTrace) {
      print('❌ Error fetching orders: $e');
      print('❌ Stack trace: $stackTrace');
      if (e is DioException && e.response != null) {
        print('❌ Response status: ${e.response?.statusCode}');
        print('❌ Response data: ${e.response?.data}');
      }
      rethrow; // Re-throw to allow proper error handling
    }
  }

  Future<CollectionOrder?> fetchOrderByCode(String code) async {
    try {
      final response = await apiService.getOrderByCode(code);
      final orderData = response.data;
      
      // Parse order items manually to extract menu_item IDs before creating OrderItem objects
      List<Map<String, dynamic>>? itemsData;
      if (orderData is Map && orderData['items'] != null) {
        itemsData = (orderData['items'] as List).map((i) {
          if (i is Map) {
            return i is Map<String, dynamic> ? i : Map<String, dynamic>.from(i);
          }
          return null;
        }).whereType<Map<String, dynamic>>().toList();
      }
      
      // Collect menu item IDs that are just integers
      Set<int> menuItemIds = {};
      if (itemsData != null) {
        for (var itemData in itemsData) {
          if (itemData['menu_item'] != null && itemData['menu_item'] is int) {
            menuItemIds.add(itemData['menu_item'] as int);
          }
        }
      }
      
      // Fetch menu items if we have IDs to look up
      Map<int, MenuItem> menuItemMap = {};
      if (menuItemIds.isNotEmpty && orderData is Map) {
        try {
          // Try to fetch menu items by the order's menu ID
          int? menuId;
          if (orderData['menu'] != null) {
            if (orderData['menu'] is Map) {
              menuId = orderData['menu']['id'];
            } else if (orderData['menu'] is int) {
              menuId = orderData['menu'];
            }
          }
          
          if (menuId != null) {
            final menuItems = await fetchMenuItems(menuId: menuId);
            menuItemMap = {for (var item in menuItems) item.id: item};
          }
        } catch (e) {
          print('⚠️ Could not fetch menu items to match names: $e');
        }
      }
      
      // Enhance order data with menu item details
      if (itemsData != null && menuItemMap.isNotEmpty) {
        for (var itemData in itemsData) {
          if (itemData['menu_item'] is int) {
            final menuItemId = itemData['menu_item'] as int;
            final menuItem = menuItemMap[menuItemId];
            if (menuItem != null) {
              // Add menu_item_name to help OrderItem.fromJson create a MenuItem
              itemData['menu_item_name'] = menuItem.name;
              itemData['menu_item_menu'] = menuItem.menu;
            }
          }
        }
      }
      
      return CollectionOrder.fromJson(orderData is Map<String, dynamic> 
          ? orderData 
          : Map<String, dynamic>.from(orderData));
    } catch (e) {
      print('❌ Error fetching order by code: $e');
      return null;
    }
  }

  Future<CollectionOrder?> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await apiService.createOrder(orderData);
      print('✅ Order created successfully. Response data type: ${response.data.runtimeType}');
      print('✅ Response data: ${response.data}');
      
      // Ensure response.data is a Map
      if (response.data is! Map<String, dynamic>) {
        print('⚠️ Warning: Response data is not a Map. Type: ${response.data.runtimeType}');
      return null;
      }
      
      return CollectionOrder.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stackTrace) {
      print('❌ Error creating order: $e');
      print('❌ Stack trace: $stackTrace');
      if (e is DioException && e.response != null) {
        print('❌ Response status: ${e.response?.statusCode}');
        print('❌ Response data: ${e.response?.data}');
      }
      rethrow; // Re-throw to allow proper error handling
    }
  }

  Future<bool> lockOrder(int orderId) async {
    try {
      await apiService.lockOrder(orderId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> unlockOrder(int orderId) async {
    try {
      await apiService.unlockOrder(orderId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markOrdered(int orderId) async {
    try {
      await apiService.markOrdered(orderId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> closeOrder(int orderId) async {
    try {
      await apiService.closeOrder(orderId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteOrder(int orderId) async {
    try {
      await apiService.deleteOrder(orderId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Restaurant>> fetchRestaurants() async {
    try {
      final response = await apiService.getRestaurants();
      final data = response.data;
      final results = data['results'] ?? data;
      if (results is List) {
        return results.map((json) => Restaurant.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Restaurant?> createRestaurant(Map<String, dynamic> data) async {
    try {
      final response = await apiService.createRestaurant(data);
      return Restaurant.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<List<Menu>> fetchMenus({int? restaurantId}) async {
    try {
      final response = await apiService.getMenus(restaurantId: restaurantId);
      final data = response.data;
      final results = data['results'] ?? data;
      if (results is List) {
        return results.map((json) => Menu.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<MenuItem>> fetchMenuItems({int? menuId, int? restaurantId}) async {
    try {
      print('🔍 Fetching menu items - menuId: $menuId, restaurantId: $restaurantId');
      final response = await apiService.getMenuItems(menuId: menuId, restaurantId: restaurantId);
      print('✅ Menu items API response status: ${response.statusCode}');
      print('✅ Menu items API response data type: ${response.data.runtimeType}');
      print('✅ Menu items API response data: ${response.data}');
      
      final data = response.data;
      
      // Handle different response structures
      dynamic results;
      if (data is Map) {
        // Check for paginated response
        if (data.containsKey('results')) {
          results = data['results'];
          print('📄 Found paginated response with ${(results as List?)?.length ?? 0} items');
        } else if (data.containsKey('data')) {
          results = data['data'];
          print('📄 Found data field with ${(results as List?)?.length ?? 0} items');
        } else {
          // Try to find any list in the response
          results = data.values.firstWhere(
            (value) => value is List,
            orElse: () => data,
          );
          print('📄 Using first list found in response');
        }
      } else if (data is List) {
        results = data;
        print('📄 Response is directly a list with ${data.length} items');
      } else {
        print('⚠️ Unexpected response type: ${data.runtimeType}');
        return [];
      }
      
      if (results is List) {
        print('📋 Processing ${results.length} items from API');
        final items = results.map((json) {
          try {
            if (json is Map) {
              // Cast to Map<String, dynamic>
              final jsonMap = json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json);
              return MenuItem.fromJson(jsonMap);
            } else {
              print('⚠️ Item is not a Map: ${json.runtimeType}');
              return null;
            }
          } catch (e, stackTrace) {
            print('❌ Error parsing menu item: $e');
            print('❌ Item JSON: $json');
            print('❌ Stack trace: $stackTrace');
            return null;
          }
        }).whereType<MenuItem>().toList();
        
        print('✅ Successfully parsed ${items.length} menu items');
        if (items.isEmpty && results.isNotEmpty) {
          print('⚠️ WARNING: API returned ${results.length} items but none could be parsed!');
          print('⚠️ First item structure: ${results.isNotEmpty ? results[0] : 'N/A'}');
        }
        return items;
      } else {
        print('⚠️ Menu items response is not a list. Type: ${results.runtimeType}, Value: $results');
        return [];
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching menu items: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }

  Future<OrderItem?> addOrderItem(Map<String, dynamic> data) async {
    try {
      final response = await apiService.createOrderItem(data);
      return OrderItem.fromJson(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<bool> removeOrderItem(int itemId) async {
    try {
      await apiService.deleteOrderItem(itemId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPendingPayments() async {
    try {
      final response = await apiService.getPendingPayments();
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<bool> markPaymentAsPaid(int paymentId) async {
    try {
      await apiService.markPaymentAsPaid(paymentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMonthlyReport({int? userId}) async {
    try {
      final response = await apiService.getMonthlyReport(userId: userId);
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<List<Recommendation>> fetchRecommendations() async {
    try {
      final response = await apiService.getRecommendations();
      final data = response.data;
      final results = data['results'] ?? data;
      if (results is List) {
        return results.map((json) => Recommendation.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createRecommendation({
    required String category,
    required String title,
    required String text,
  }) async {
    try {
      await apiService.createRecommendation({
        'category': category,
        'title': title,
        'text': text,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<User>> fetchUsers() async {
    try {
      final response = await apiService.getUsers();
      final data = response.data;
      
      // Handle different response structures
      dynamic results;
      if (data is Map) {
        if (data.containsKey('results')) {
          results = data['results'];
        } else {
          results = data;
        }
      } else if (data is List) {
        results = data;
      } else {
        print('⚠️ Unexpected users response type: ${data.runtimeType}');
        print('⚠️ Users response data: $data');
        return [];
      }
      
      if (results is List) {
        return results.map((json) {
          try {
            if (json is Map) {
              final jsonMap = json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json);
              return User.fromJson(jsonMap);
            }
            return null;
          } catch (e) {
            print('❌ Error parsing user: $e, user data: $json');
            return null;
          }
        }).whereType<User>().toList();
      }
      return [];
    } catch (e, stackTrace) {
      print('❌ Error fetching users: $e');
      print('❌ Stack trace: $stackTrace');
      return [];
    }
  }
}

