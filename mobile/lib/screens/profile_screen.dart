import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notifications_provider.dart';
import 'restaurant_wheel_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _instapayLinkController = TextEditingController();
  File? _selectedQrImage;
  String? _currentQrCodeUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        _instapayLinkController.text = authProvider.user?.instapayLink ?? '';
        _currentQrCodeUrl = authProvider.user?.instapayQrCodeUrl ?? authProvider.user?.instapayQrCode;
      }
    });
  }

  @override
  void dispose() {
    _instapayLinkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedQrImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveInstapaySettings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user == null) return;

      final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
      final user = authProvider.user!;
      
      // Always include username and other required fields when updating
      final baseData = {
        'username': user.username,
        'email': user.email,
        'first_name': user.firstName ?? '',
        'last_name': user.lastName ?? '',
        'instapay_link': _instapayLinkController.text.trim(),
      };

      FormData? formData;

      if (_selectedQrImage != null) {
        // If we have an image, use FormData
        formData = FormData.fromMap(baseData);
        formData.files.add(MapEntry(
          'instapay_qr_code',
          await MultipartFile.fromFile(_selectedQrImage!.path),
        ));
        
        await ordersProvider.ordersService.apiService.updateUser(
          user.id,
          {},
          formData: formData,
        );
      } else {
        // If no image, use regular data
        await ordersProvider.ordersService.apiService.updateUser(
          user.id,
          baseData,
        );
      }
      
      // Refresh user data
      await authProvider.fetchUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Instapay settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedQrImage = null;
          _currentQrCodeUrl = authProvider.user?.instapayQrCodeUrl ?? authProvider.user?.instapayQrCode;
        });
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildBottomNavBar() {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 4; // Default to Profile
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
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: _SwipeableScreen(
        onSwipeRight: () {
          // Swipe right = go back to wheel
          context.go('/wheel');
        },
        child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;

          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Username: ${user.username}'),
                      Text('Email: ${user.email}'),
                      if (user.firstName != null) Text('First Name: ${user.firstName}'),
                      if (user.lastName != null) Text('Last Name: ${user.lastName}'),
                      Text('Role: ${user.role}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.payment),
                title: const Text('Pending Payments'),
                onTap: () => context.push('/pending-payments'),
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Reports'),
                onTap: () => context.push('/reports'),
              ),
              ListTile(
                leading: const Icon(Icons.recommend),
                title: const Text('Recommendations'),
                onTap: () => context.push('/recommendations'),
              ),
              if (authProvider.isManager || authProvider.isAdmin) ...[
                ListTile(
                  leading: const Icon(Icons.restaurant),
                  title: const Text('Restaurants'),
                  onTap: () => context.push('/restaurants'),
                ),
              ],
              if (authProvider.isAdmin) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Create User'),
                  onTap: () => context.push('/register'),
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('User Management'),
                  onTap: () => context.push('/users'),
                ),
              ],
              const Divider(),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return SwitchListTile(
                    secondary: Icon(
                      themeProvider.themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : Icons.light_mode,
                    ),
                    title: const Text('Dark Mode'),
                    subtitle: Text(
                      themeProvider.themeMode == ThemeMode.dark
                          ? 'Dark'
                          : themeProvider.themeMode == ThemeMode.light
                              ? 'Light'
                              : 'System',
                    ),
                    value: themeProvider.themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      themeProvider.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  );
                },
              ),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return ListTile(
                    leading: const Icon(Icons.brightness_auto),
                    title: const Text('Use System Theme'),
                    trailing: Radio<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          themeProvider.setThemeMode(value);
                        }
                      },
                    ),
                  );
                },
              ),
              const Divider(),
              // Instapay Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.payment, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Instapay Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _instapayLinkController,
                        decoration: const InputDecoration(
                          labelText: 'Instapay Link',
                          hintText: 'https://ipn.eg/S/...',
                          border: OutlineInputBorder(),
                          helperText: 'Your Instapay payment link',
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'QR Code Image',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.image),
                              label: Text(_selectedQrImage != null
                                  ? 'Change Image'
                                  : 'Select Image'),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedQrImage != null) ...[
                        const SizedBox(height: 8),
                        Image.file(
                          _selectedQrImage!,
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                      ] else if (_currentQrCodeUrl != null && _currentQrCodeUrl!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Image.network(
                          _currentQrCodeUrl!,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Text('Failed to load image');
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveInstapaySettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Instapay Settings'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  // Disconnect notifications WebSocket before logout
                  final notificationsProvider = Provider.of<NotificationsProvider>(context, listen: false);
                  notificationsProvider.disconnectWebSocket();
                  
                  await authProvider.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          );
        },
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      ),
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
            // Swipe right
            onSwipeRight!();
          } else if (details.primaryVelocity! < -500 && onSwipeLeft != null) {
            // Swipe left
            onSwipeLeft!();
          }
        }
      },
      child: child,
    );
  }
}

