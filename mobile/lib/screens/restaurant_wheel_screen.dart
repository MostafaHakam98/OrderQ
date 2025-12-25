import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../providers/orders_provider.dart';
import '../models/restaurant.dart';

class RestaurantWheelScreen extends StatefulWidget {
  const RestaurantWheelScreen({Key? key}) : super(key: key);

  @override
  State<RestaurantWheelScreen> createState() => _RestaurantWheelScreenState();
}

class _RestaurantWheelScreenState extends State<RestaurantWheelScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _confettiAnimation;
  bool _isSpinning = false;
  Restaurant? _selectedRestaurant;
  Set<int> _selectedRestaurantIds = {};
  List<Restaurant> _availableRestaurants = [];
  double _finalRotation = 0.0;
  List<Restaurant> _pickHistory = []; // History of recent picks
  bool _isRestaurantListExpanded = false; // Track expansion state

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _confettiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiController, curve: Curves.easeOut),
    );
    
    // Add listener to stop pulse animation when spinning
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.forward) {
        _pulseController.stop();
      } else if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _pulseController.repeat(reverse: true);
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRestaurants();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    if (ordersProvider.restaurants.isEmpty) {
      await ordersProvider.fetchRestaurants();
    }
    setState(() {
      _availableRestaurants = ordersProvider.restaurants;
      // Select all restaurants by default
      _selectedRestaurantIds = Set.from(_availableRestaurants.map((r) => r.id));
    });
  }

  void _spinWheel() {
    if (_isSpinning || _selectedRestaurantIds.isEmpty) return;
    
    // Haptic feedback
    HapticFeedback.mediumImpact();

    final selectedRestaurants = _availableRestaurants
        .where((r) => _selectedRestaurantIds.contains(r.id))
        .toList();

    if (selectedRestaurants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one restaurant'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSpinning = true;
      _selectedRestaurant = null;
    });

    // Random rotation (multiple full spins + random angle)
    final random = math.Random();
    final baseRotations = 5.0 + random.nextDouble() * 2; // 5-7 full rotations
    
    // Pre-select a random restaurant
    final selectedIndex = random.nextInt(selectedRestaurants.length);
    final restaurant = selectedRestaurants[selectedIndex];
    
    // Calculate the angle to land on this restaurant
    // Pointer is at top (pointing down, which is at angle -π/2 or 270°)
    // WheelPainter draws segments starting from -π/2 (top), so:
    // - Segment 0 starts at -π/2
    // - Segment i starts at i * sectorSize - π/2
    // - Segment i's center is at: i * sectorSize - π/2 + sectorSize/2
    final sectorSize = (2 * math.pi) / selectedRestaurants.length;
    
    // Transform.rotate rotates COUNTER-CLOCKWISE for positive angles
    // The selected segment's center angle (before rotation) is:
    // selectedIndex * sectorSize - π/2 + sectorSize/2
    // After rotating counter-clockwise by θ, it becomes:
    // (selectedIndex * sectorSize - π/2 + sectorSize/2) + θ
    // We want this to equal -π/2 (where the pointer is)
    // So: (selectedIndex * sectorSize - π/2 + sectorSize/2) + θ = -π/2
    // Therefore: θ = -selectedIndex * sectorSize - sectorSize/2
    // 
    // To get a positive rotation, we add full rotations:
    // θ = (baseRotations * 2 * π) - (selectedIndex * sectorSize) - (sectorSize / 2)
    final targetAngle = selectedIndex * sectorSize + sectorSize / 2;
    
    // Subtract target angle to rotate counter-clockwise to align with pointer
    _finalRotation = (baseRotations * 2 * math.pi) - targetAngle;
    
    // Ensure positive rotation by adding 2π if needed
    while (_finalRotation < 0) {
      _finalRotation += 2 * math.pi;
    }

    _spinController.reset();
    _spinController.forward().then((_) {
      // Haptic feedback on completion
      HapticFeedback.heavyImpact();
      
      setState(() {
        _selectedRestaurant = restaurant;
        _isSpinning = false;
        // Add to history (keep last 5)
        _pickHistory.insert(0, restaurant);
        if (_pickHistory.length > 5) {
          _pickHistory.removeLast();
        }
      });

      // Show celebration
      _showConfetti();
      _showCelebration(restaurant);
    });
  }

  void _showConfetti() {
    _confettiController.forward(from: 0).then((_) {
      _confettiController.reverse();
    });
  }

  void _showCelebration(Restaurant restaurant) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.celebration,
              size: 64,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              '🎉 Today\'s Restaurant! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                restaurant.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check),
              label: const Text('Awesome!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
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
          'Wheel',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurants,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _SwipeableScreen(
        onSwipeLeft: () {
          // Swipe left = go to profile
          context.go('/profile');
        },
        onSwipeRight: () {
          // Swipe right = go back to orders
          context.go('/orders');
        },
        child: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.restaurants.isEmpty && !ordersProvider.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No restaurants available',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadRestaurants,
                    child: const Text('Load Restaurants'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Wheel at the top
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text(
                          'Spin the Wheel!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: 320,
                          height: 320,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              // Pointer at the top
                              Positioned(
                                top: -5,
                                child: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _isSpinning ? 1.0 : _pulseAnimation.value,
                                      child: SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: CustomPaint(
                                          painter: PointerPainter(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              // Wheel
                              Positioned(
                                top: 25,
                                child: AnimatedBuilder(
                                  animation: _rotationAnimation,
                                  builder: (context, child) {
                                    final selectedRestaurants = _availableRestaurants
                                        .where((r) =>
                                            _selectedRestaurantIds.contains(r.id))
                                        .toList();
                                    if (selectedRestaurants.isEmpty) {
                                      return const SizedBox(
                                        width: 300,
                                        height: 300,
                                        child: Center(
                                          child: Text('Select restaurants to spin'),
                                        ),
                                      );
                                    }

                                    // Use the pre-calculated final rotation
                                    final rotation = _rotationAnimation.value * _finalRotation;

                                    return Transform.rotate(
                                      angle: rotation,
                                      child: Container(
                                        width: 300,
                                        height: 300,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: CustomPaint(
                                          size: const Size(300, 300),
                                          painter: WheelPainter(selectedRestaurants),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_selectedRestaurant != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Selected Restaurant:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedRestaurant!.name,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[900],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isSpinning || _selectedRestaurantIds.isEmpty
                                    ? null
                                    : () {
                                        HapticFeedback.mediumImpact();
                                        _spinWheel();
                                      },
                            icon: _isSpinning
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.casino, size: 28),
                            label: Text(
                              _isSpinning ? 'Spinning...' : '🎰 Spin the Wheel!',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(35),
                              ),
                              elevation: _isSpinning ? 2 : 8,
                              shadowColor: Colors.orange.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Restaurant selection (collapsible)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _isRestaurantListExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          _isRestaurantListExpanded = expanded;
                        });
                        HapticFeedback.selectionClick();
                      },
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      leading: Icon(Icons.restaurant_menu, color: Colors.orange[700]),
                      title: const Text(
                        'Select Restaurants',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${_selectedRestaurantIds.length} restaurant(s) selected',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(
                        _isRestaurantListExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.orange[700],
                      ),
                      children: [
                        // Select/Deselect All button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                if (_selectedRestaurantIds.length ==
                                    _availableRestaurants.length) {
                                  _selectedRestaurantIds.clear();
                                } else {
                                  _selectedRestaurantIds = Set.from(
                                      _availableRestaurants.map((r) => r.id));
                                }
                              });
                            },
                            icon: Icon(
                              _selectedRestaurantIds.length ==
                                      _availableRestaurants.length
                                  ? Icons.check_box_outlined
                                  : Icons.check_box,
                              size: 20,
                            ),
                            label: Text(
                              _selectedRestaurantIds.length ==
                                      _availableRestaurants.length
                                  ? 'Deselect All'
                                  : 'Select All',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              side: BorderSide(
                                color: Colors.orange[700]!,
                                width: 2,
                              ),
                              foregroundColor: Colors.orange[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_availableRestaurants.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          ..._availableRestaurants.map((restaurant) {
                            final isSelected =
                                _selectedRestaurantIds.contains(restaurant.id);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (value == true) {
                                    _selectedRestaurantIds.add(restaurant.id);
                                  } else {
                                    _selectedRestaurantIds.remove(restaurant.id);
                                  }
                                  // Reset selection when restaurants change
                                  _selectedRestaurant = null;
                                });
                              },
                              title: Text(restaurant.name),
                              activeColor: Colors.orange,
                              contentPadding: EdgeInsets.zero,
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                // Pick History
                if (_pickHistory.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, color: Colors.teal[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Recent Picks',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ..._pickHistory.asMap().entries.map((entry) {
                            final index = entry.key;
                            final restaurant = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: index == 0 ? Colors.teal[300]! : Colors.grey[300]!,
                                  width: index == 0 ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: index == 0 ? Colors.teal[100] : Colors.grey[200],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: index == 0 ? Colors.teal[900] : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      restaurant.name,
                                      style: TextStyle(
                                        fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                                        fontSize: index == 0 ? 16 : 14,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ),
                                  if (index == 0)
                                    Icon(Icons.star, color: Colors.teal[700], size: 20),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final location = GoRouterState.of(context).uri.path;
    int currentIndex = 1; // Default to Wheel
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

class WheelPainter extends CustomPainter {
  final List<Restaurant> restaurants;
  final List<List<Color>> colorGradients = [
    [Colors.blue[400]!, Colors.blue[600]!],
    [Colors.green[400]!, Colors.green[600]!],
    [Colors.orange[400]!, Colors.orange[600]!],
    [Colors.purple[400]!, Colors.purple[600]!],
    [Colors.red[400]!, Colors.red[600]!],
    [Colors.teal[400]!, Colors.teal[600]!],
    [Colors.pink[400]!, Colors.pink[600]!],
    [Colors.amber[400]!, Colors.amber[600]!],
    [Colors.indigo[400]!, Colors.indigo[600]!],
    [Colors.cyan[400]!, Colors.cyan[600]!],
  ];

  WheelPainter(this.restaurants);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 15;

    // Draw wheel segments
    final sectorAngle = (2 * math.pi) / restaurants.length;

    for (int i = 0; i < restaurants.length; i++) {
      final startAngle = i * sectorAngle - math.pi / 2;
      final colors = colorGradients[i % colorGradients.length];

      // Draw segment with gradient
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sectorAngle,
          colors: colors,
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        rect,
        startAngle,
        sectorAngle,
        true,
        paint,
      );

      // Draw border
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      canvas.drawArc(
        rect,
        startAngle,
        sectorAngle,
        true,
        borderPaint,
      );

      // Draw restaurant name - rotated to align with segment
      final textAngle = startAngle + sectorAngle / 2;
      final textRadius = radius * 0.65;
      
      // Save canvas state
      canvas.save();
      
      // Move to center and rotate to align text with segment
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle + math.pi / 2); // Rotate to align with segment
      
      // Draw text
      final textPainter = TextPainter(
        text: TextSpan(
          text: restaurants[i].name.length > 12
              ? '${restaurants[i].name.substring(0, 12)}...'
              : restaurants[i].name,
          style: TextStyle(
            color: Colors.white,
            fontSize: restaurants.length > 6 ? 12 : 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: [
              const Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(maxWidth: radius * 0.8);
      textPainter.paint(
        canvas,
        Offset(
          -textPainter.width / 2,
          -textRadius - textPainter.height / 2,
        ),
      );
      
      // Restore canvas state
      canvas.restore();
    }

    // Draw outer circle with gradient
    final outerPaint = Paint()
      ..color = Colors.grey[800]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(center, radius, outerPaint);
    
    // Draw inner circle (center)
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.15, innerPaint);
    
    final innerBorderPaint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius * 0.15, innerBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is WheelPainter) {
      return oldDelegate.restaurants.length != restaurants.length ||
          oldDelegate.restaurants != restaurants;
    }
    return true;
  }
}

// Pointer painter for the arrow at the top
class PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red[600]!
      ..style = PaintingStyle.fill;

    final path = Path();
    // Draw arrow pointing down
    path.moveTo(25, 0); // Top center
    path.lineTo(0, 30); // Bottom left
    path.lineTo(10, 30); // Inner left
    path.lineTo(10, 50); // Bottom left
    path.lineTo(40, 50); // Bottom right
    path.lineTo(40, 30); // Inner right
    path.lineTo(50, 30); // Bottom right
    path.close();

    canvas.drawPath(path, paint);
    
    // Add shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    final shadowPath = Path();
    shadowPath.addPath(path, const Offset(2, 2));
    canvas.drawPath(shadowPath, shadowPaint);
    
    // Draw highlight
    final highlightPaint = Paint()
      ..color = Colors.red[300]!.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final highlightPath = Path();
    highlightPath.moveTo(25, 5);
    highlightPath.lineTo(15, 25);
    highlightPath.lineTo(35, 25);
    highlightPath.close();
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

