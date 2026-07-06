import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosk/menu_item_dialog.dart';
import 'package:provider/provider.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/pages/settings_page.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/menu_grid.dart';
import 'package:kiosk/shopping_cart_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kiosk/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiosk/pages/order_history_page.dart';
import 'package:kiosk/widgets/custom_dialog.dart';
import 'package:kiosk/widgets/pin_dialog.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  if (!kIsWeb && Platform.isAndroid) {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (context) => ShoppingCart(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kiosk',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const KioskHomePage(),
    );
  }
}

class KioskHomePage extends StatefulWidget {
  const KioskHomePage({super.key});

  @override
  State<KioskHomePage> createState() => _KioskHomePageState();
}

class _KioskHomePageState extends State<KioskHomePage> {
  List<String> _categories = [];
  Map<String, List<MenuItem>> _menuItems = {};
  bool _isLoading = true;
  String _tableNumber = '';
  String _restaurantName = '';
  String? _imageFolderPath;
  bool _hasOrders = false;
  bool _showCart = false;
  bool _showWelcome = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadSettings();
    await _loadData();
    await _checkOrderHistory();
  }

  Future<void> _checkOrderHistory() async {
    if (_restaurantName.isEmpty || _tableNumber.isEmpty) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantName', isEqualTo: _restaurantName)
        .where('tableNumber', isEqualTo: _tableNumber)
        .where('completed', isEqualTo: false)
        .limit(1)
        .get();

    if (mounted) {
      setState(() {
        _hasOrders = snapshot.docs.isNotEmpty;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tableNumber = prefs.getString('tableNumber') ?? '';
      _restaurantName = prefs.getString('restaurantName') ?? '';
      _imageFolderPath = prefs.getString('imageFolderPath');
    });
  }

  Future<void> _loadData() async {
    if (_restaurantName.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final restaurantRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantName);
      final docSnapshot = await restaurantRef.get();

      List<String> categories = [];
      if (docSnapshot.exists && docSnapshot.data()!.containsKey('categories')) {
        categories = List<String>.from(docSnapshot.data()!['categories']);
      }

      final menuItemsSnapshot = await restaurantRef
          .collection('menuItems')
          .get();
      final Map<String, List<MenuItem>> menuItems = {};
      for (final doc in menuItemsSnapshot.docs) {
        final item = MenuItem.fromJson(doc.data());
        if (menuItems.containsKey(item.category)) {
          menuItems[item.category]!.add(item);
        } else {
          menuItems[item.category] = [item];
        }
      }

      setState(() {
        _categories = categories;
        _menuItems = menuItems;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data from Firestore: $e");
      setState(() {
        _isLoading = false;
        // Optionally, show an error message to the user
      });
    }
  }

  Future<void> _saveData() async {
    if (_restaurantName.isEmpty) {
      // This case is handled by the UI, but as a safeguard:
      if (navigatorKey.currentContext != null) {
        showCustomDialog(
          context: navigatorKey.currentContext!,
          title: '저장 실패',
          content: '음식점 이름이 설정되지 않았습니다.',
        );
      }
      return;
    }

    try {
      final restaurantRef = FirebaseFirestore.instance
          .collection('restaurants')
          .doc(_restaurantName);

      final batch = FirebaseFirestore.instance.batch();

      // Save categories
      batch.set(restaurantRef, {
        'categories': _categories,
      }, SetOptions(merge: true));

      // Save menu items
      final menuItemsRef = restaurantRef.collection('menuItems');
      final currentMenuItemsSnapshot = await menuItemsRef.get();
      final currentMenuItemIds = currentMenuItemsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();
      final updatedMenuItemNames = <String>{};

      for (final category in _categories) {
        if (_menuItems[category] == null) continue;
        for (final item in _menuItems[category]!) {
          final menuItemDocRef = menuItemsRef.doc(item.name);
          batch.set(menuItemDocRef, item.toJson());
          updatedMenuItemNames.add(item.name);
        }
      }

      // Delete menu items that are no longer in the list
      final itemsToDelete = currentMenuItemIds.difference(updatedMenuItemNames);
      for (final itemId in itemsToDelete) {
        batch.delete(menuItemsRef.doc(itemId));
      }

      await batch.commit();

      if (navigatorKey.currentContext != null) {
        showCustomDialog(
          context: navigatorKey.currentContext!,
          title: '저장 완료',
          content: '데이터가 에 성공적으로 저장되었습니다.',
        );
      }
    } catch (e) {
      if (navigatorKey.currentContext != null) {
        showCustomDialog(
          context: navigatorKey.currentContext!,
          title: '저장 오류',
          content: ' 저장 중 오류가 발생했습니다: $e',
        );
      }
    }
  }

  void _updateCategoriesAndMenus(
    List<String> newCategories,
    Map<String, List<MenuItem>> newMenuItems,
  ) {
    setState(() {
      _categories = newCategories;
      _menuItems = newMenuItems;
    });
    _saveData();
  }

  Future<String> _getAdminPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('adminPin') ?? '0000'; // Default PIN is '0000'
  }

  Future<void> _submitOrder(String paymentMethod) async {
    final cart = context.read<ShoppingCart>();
    if (cart.items.isEmpty) {
      return;
    }

    final orderData = {
      'orderTime': Timestamp.now(),
      'restaurantName': _restaurantName,
      'tableNumber': _tableNumber,
      'completed': false,
      'items': cart.items
          .map(
            (cartItem) => {
              'name': cartItem.item.name,
              'quantity': cartItem.quantity,
              'price': cartItem.item.price,
            },
          )
          .toList(),
      'totalPrice': cart.totalPrice,
      'paymentMethod': paymentMethod,
    };

    try {
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      cart.clearCart();

      if (mounted) {
        showCustomDialog(
          context: context,
          title: '주문 완료',
          content: '주문이 성공적으로 완료되었습니다!',
        );
        setState(() {
          _showCart = false;
          _showWelcome = true;
        });
        _checkOrderHistory();
      }
    } catch (e) {
      if (mounted) {
        showCustomDialog(
          context: context,
          title: '오류',
          content: '주문 처리 중 오류가 발생했습니다: $e',
        );
      }
    }
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.5,
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.money, size: 48),
                    label: const Text('현금결제', style: TextStyle(fontSize: 24)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitOrder('현금결제');
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 48),
                    label: const Text('페이결제', style: TextStyle(fontSize: 24)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showPayPaymentDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPayPaymentDialog() {
    final cart = context.read<ShoppingCart>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PayPaymentDialog(
          totalPrice: cart.totalPrice,
          onSubmit: (paymentMethod) => _submitOrder(paymentMethod),
          restaurantName: _restaurantName,
        );
      },
    );
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left side: Tap to start
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _showWelcome = false;
                });
              },
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '기 다 리 지  말 고 !',
                        style: TextStyle(
                          fontSize: 36,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey[600],
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        '터치 후',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE55A44), // Orange-red color
                        ),
                      ),
                      const Text(
                        '주문하세요',
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E2022), // Deep dark color
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Right side: Kiosk Steps sidebar
          Container(
            width: 220,
            color: const Color(0xFF1D2026), // Dark charcoal color
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 15),
            child: Column(
              children: [
                // Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'easy',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    Text(
                      'KIOSK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Step 1
                _buildSidebarStep(
                  icon: Icons.touch_app,
                  label: '화면터치',
                  isActive: true,
                ),
                _buildStepConnector(),
                // Step 2
                _buildSidebarStep(
                  icon: Icons.restaurant_menu,
                  label: '상품선택',
                  isActive: false,
                ),
                _buildStepConnector(),
                // Step 3
                _buildSidebarStep(
                  icon: Icons.credit_card,
                  label: '결제/주문서확인',
                  isActive: false,
                ),
                _buildStepConnector(),
                // Step 4
                _buildSidebarStep(
                  icon: Icons.check_circle_outline,
                  label: '주문완료',
                  isActive: false,
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarStep({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE55A44) : Colors.grey[800],
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFE55A44).withOpacity(0.4),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Icon(
        Icons.keyboard_arrow_down,
        color: Colors.grey[600],
        size: 20,
      ),
    );
  }

  Widget _buildCartPanel(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ko_KR');
    return Consumer<ShoppingCart>(
      builder: (context, cart, child) {
        return Column(
          children: [
            // Dark Header
            Container(
              color: const Color(0xFF1D2026),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    '장바구니 (${cart.itemCount})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (cart.items.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        cart.clearCart();
                        showCustomDialog(
                          context: context,
                          title: '알림',
                          content: '장바구니가 비워졌습니다.',
                        );
                      },
                      style: TextButton.styleFrom(
                        side: const BorderSide(color: Colors.white70, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        '장바구니 비우기',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () {
                      setState(() {
                        _showCart = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Items List
            Expanded(
              child: cart.items.isEmpty
                  ? const Center(
                      child: Text(
                        '장바구니가 비어있습니다.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: cart.items.length,
                      separatorBuilder: (context, index) => const Divider(height: 30, thickness: 1),
                      itemBuilder: (context, index) {
                        final cartItem = cart.items[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    cartItem.item.name,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF007A87),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.grey, size: 24),
                                  onPressed: () {
                                    cart.removeItem(cartItem);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        cart.decreaseQuantity(cartItem);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey[400]!),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(Icons.remove, size: 20, color: Colors.grey),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        '${cartItem.quantity}',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        cart.increaseQuantity(cartItem);
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey[400]!),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: const Icon(Icons.add, size: 20, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${currencyFormat.format(cartItem.item.price * cartItem.quantity)}원',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFF007A87),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const Divider(thickness: 1.5, height: 1),
            // Bottom section
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '총 금액',
                        style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${currencyFormat.format(cart.totalPrice)}원',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Large Order Button
            SizedBox(
              width: double.infinity,
              height: 70,
              child: ElevatedButton(
                onPressed: cart.items.isEmpty ? null : _showPaymentDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE55A44),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '주문하기',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNormalPanel(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_tableNumber.isNotEmpty)
              Text(
                '테이블: $_tableNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                final adminPin = await _getAdminPin();
                final bool? isCorrect = await showDialog<bool>(
                  context: context,
                  builder: (context) => PinDialog(correctPin: adminPin),
                );

                if (isCorrect == true) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsPage(
                        categories: _categories,
                        menuItems: _menuItems,
                        onUpdate: _updateCategoriesAndMenus,
                        imageFolderPath: _imageFolderPath,
                      ),
                    ),
                  );
                  await _loadSettings(); // Reload settings after returning from SettingsPage
                  await _loadData(); // Reload data for the new restaurant name
                  _checkOrderHistory();
                } else if (isCorrect == false) {
                  showCustomDialog(
                    context: context,
                    title: 'PIN 오류',
                    content: '잘못된 PIN 번호입니다.',
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () async {
            if (_restaurantName.isNotEmpty && _tableNumber.isNotEmpty) {
              await FirebaseFirestore.instance.collection('calls').add({
                'restaurantName': _restaurantName,
                'tableNumber': _tableNumber,
                'time': Timestamp.now(),
                'confirmed': false,
              });
              showCustomDialog(
                context: context,
                title: '직원 호출',
                content: '직원을 호출했습니다. 잠시만 기다려주세요.',
              );
            } else {
              showCustomDialog(
                context: context,
                title: '알림',
                content: '음식점 이름과 테이블 번호를 먼저 설정해주세요.',
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[800],
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text(
            '직원호출',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 80,
          child: ElevatedButton(
            onPressed: _hasOrders
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderHistoryPage(
                          restaurantName: _restaurantName,
                          tableNumber: _tableNumber,
                        ),
                      ),
                    );
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              '주문내역',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 120,
          child: Consumer<ShoppingCart>(
            builder: (context, cart, child) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showCart = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '주문하기',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      return _buildWelcomeScreen(context);
    }
    // Rebuild the DefaultTabController whenever the number of categories changes.
    return DefaultTabController(
      key: ValueKey(_categories.length),
      length: _categories.length,
      child: Scaffold(
        body: Row(
          children: [
            Expanded(
              child: SafeArea(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 48),
                              Expanded(
                                child: TabBar(
                                  isScrollable: true,
                                  labelStyle: const TextStyle(fontSize: 20),
                                  tabs: _categories
                                      .map((String name) => Tab(text: name))
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: _categories.isEmpty
                                ? const Center(
                                    child: Text(
                                      '메뉴가 없습니다. 설정에서 카테고리와 메뉴를 추가해주세요.',
                                    ),
                                  )
                                : TabBarView(
                                    children: _categories.map((String name) {
                                      return MenuGrid(
                                        items: _menuItems[name] ?? [],
                                        imageFolderPath: _imageFolderPath,
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _showCart ? MediaQuery.of(context).size.width * 0.48 : 220,
              padding: _showCart ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: BoxDecoration(
                color: _showCart ? Colors.white : Colors.grey[100],
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
              ),
              child: _showCart ? _buildCartPanel(context) : _buildNormalPanel(context),
            ),
          ],
        ),
      ),
    );
  }
}
