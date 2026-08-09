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
import 'package:kiosk/pages/fun_page.dart';
import 'package:kiosk/pages/owner_mode_page.dart';
import 'package:kiosk/pages/order_completed_page.dart';
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
  static final GlobalKey cartTargetKey = GlobalKey();

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
  String _activeSidebarTab = 'menu';

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
      _tableNumber = prefs.getString('tableNumber') ?? '2';
      if (_tableNumber.isEmpty) _tableNumber = '2';
      _restaurantName = prefs.getString('restaurantName') ?? '조이김밥';
      if (_restaurantName.isEmpty) _restaurantName = '조이김밥';
      _imageFolderPath = prefs.getString('imageFolderPath');
    });

    if (_imageFolderPath == null || _imageFolderPath!.isEmpty) {
      if (kIsWeb) {
        _imageFolderPath = 'web_images';
        await prefs.setString('imageFolderPath', _imageFolderPath!);
      } else {
        String defaultPath;
        if (Platform.isAndroid) {
          defaultPath = '/storage/emulated/0/table_order';
        } else {
          final docDir = await getApplicationDocumentsDirectory();
          defaultPath = '${docDir.path}/table_order';
        }

        try {
          final directory = Directory(defaultPath);
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
        } catch (e) {
          // Ignored
        }

        await prefs.setString('imageFolderPath', defaultPath);
        setState(() {
          _imageFolderPath = defaultPath;
        });
      }
    }

    if (!kIsWeb && _imageFolderPath != null && _imageFolderPath!.isNotEmpty) {
      try {
        final restFolder = Directory('$_imageFolderPath/$_restaurantName');
        if (!await restFolder.exists()) {
          await restFolder.create(recursive: true);
        }
      } catch (e) {
        // Ignored
      }
    }

    await prefs.setString('restaurantName', _restaurantName);
    await prefs.setString('tableNumber', _tableNumber);
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

      if (_restaurantName == '조이김밥' && (categories.isEmpty || menuItemsSnapshot.docs.isEmpty)) {
        categories = ['김밥', '분식', '음료'];
        await restaurantRef.set({'categories': categories}, SetOptions(merge: true));

        final defaultItems = [
          MenuItem(name: '조이김밥', category: '김밥', price: 3500, description: '정갈하고 든든한 기본 야채 김밥', image: 'assets/images/joy_gimbap.png', order: 1),
          MenuItem(name: '참치김밥', category: '김밥', price: 4500, description: '참치마요를 듬뿍 넣어 부드러운 김밥', image: 'assets/images/tuna_gimbap.png', order: 2),
          MenuItem(name: '치즈김밥', category: '김밥', price: 4200, description: '부드러운 체다치즈가 들어간 고소한 김밥', image: 'assets/images/cheese_gimbap.png', order: 3),
          MenuItem(name: '김치김밥', category: '김밥', price: 4200, description: '매콤 칼칼한 김치가 아삭 씹히는 김밥', image: 'assets/images/kimchi_gimbap.png', isNew: true, order: 4),
          MenuItem(name: '돈가스김밥', category: '김밥', price: 4800, description: '바삭하고 두툼한 돈가스가 들어간 김밥', image: 'assets/images/tonkatsu_gimbap.png', isBest: true, order: 5),
          MenuItem(name: '스팸김밥', category: '김밥', price: 4500, description: '짭조름하고 고소한 스팸이 듬뿍 들어간 김밥', image: 'assets/images/spam_gimbap.png', order: 6),

          MenuItem(name: '국물떡볶이', category: '분식', price: 5000, description: '매콤달콤한 국물 떡볶이', image: 'assets/images/tteokbokki.png', isBest: true, order: 1),
          MenuItem(name: '모듬튀김', category: '분식', price: 4500, description: '바삭하게 튀겨낸 다양한 튀김', image: 'assets/images/fried_platter.png', order: 2),
          MenuItem(name: '찰순대', category: '분식', price: 4000, description: '쫄깃하고 맛있는 전통 순대', image: 'assets/images/soondae.png', order: 3),

          MenuItem(name: '콜라', category: '음료', price: 2000, description: '시원한 캔 콜라', image: 'assets/images/cola.png', order: 1),
          MenuItem(name: '사이다', category: '음료', price: 2000, description: '청량한 캔 사이다', image: 'assets/images/cider.png', order: 2),
          MenuItem(name: '쿨피스', category: '음료', price: 1500, description: '달콤하고 상큼한 쿨피스', image: 'assets/images/coolpis.png', order: 3),
        ];

        final batch = FirebaseFirestore.instance.batch();
        for (final item in defaultItems) {
          final docRef = restaurantRef.collection('menuItems').doc(item.name);
          batch.set(docRef, item.toJson());
        }
        await batch.commit();

        menuItems.clear();
        for (final item in defaultItems) {
          if (!menuItems.containsKey(item.category)) {
            menuItems[item.category] = [];
          }
          menuItems[item.category]!.add(item);
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
      final List<CartItem> orderedItems = List.from(cart.items);
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      cart.clearCart();

      if (mounted) {
        setState(() {
          _showCart = false;
          _showWelcome = true;
        });
        _checkOrderHistory();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderCompletedPage(
              tableNumber: _tableNumber,
              orderedItems: orderedItems,
              imageFolderPath: _imageFolderPath != null && _imageFolderPath!.isNotEmpty
                  ? '$_imageFolderPath/$_restaurantName'
                  : null,
            ),
          ),
        );
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

  Future<void> _showChangeTableNumberDialog() async {
    final currentNumStr = _tableNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final int currentNum = int.tryParse(currentNumStr) ?? 2;

    final newTable = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E202C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '테이블 번호 선택',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이 기기에서 사용할 테이블 번호를 선택해주세요.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 260,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: 25,
                    itemBuilder: (context, index) {
                      final num = index + 1;
                      final isSelected = (num == currentNum);
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? const Color(0xFF007A87) : const Color(0xFF2C2E3E),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, '$num');
                        },
                        child: Text(
                          '$num번',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('취소', style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );

    if (newTable != null && newTable.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tableNumber', newTable);
      setState(() {
        _tableNumber = newTable;
      });
    }
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
                onPressed: cart.items.isEmpty
                    ? null
                    : () {
                        if (_restaurantName.isEmpty || _tableNumber.isEmpty) {
                          showCustomDialog(
                            context: context,
                            title: '알림',
                            content: '음식점 이름과 테이블 번호를 먼저 설정해주세요.',
                          );
                          return;
                        }
                        _submitOrder('주문');
                      },
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

  Widget _buildLeftSidebar(BuildContext context) {
    return Container(
      width: 110,
      color: const Color(0xFF1E202C), // Dark charcoal/navy color
      child: Column(
        children: [
          // Logo / Header
          GestureDetector(
            onLongPress: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OwnerModePage(
                    restaurantName: _restaurantName,
                    categories: _categories,
                    menuItems: _menuItems,
                    imageFolderPath: _imageFolderPath,
                    onUpdate: _updateCategoriesAndMenus,
                  ),
                ),
              );
              await _loadSettings();
              await _loadData();
              _checkOrderHistory();
            },
            child: Container(
              width: double.infinity,
              height: 100,
              color: Colors.white,
              alignment: Alignment.center,
              child: const Text(
                '조이\n오더',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Restaurant and Table info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              _restaurantName.isEmpty ? '조이김밥' : _restaurantName,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onLongPress: _showChangeTableNumberDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2E3E),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _tableNumber.isEmpty ? '2번 테이블' : (_tableNumber.contains('테이블') ? _tableNumber : '$_tableNumber번 테이블'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          // Sidebar menu items
          // 1. 메뉴주문 (Active)
          _buildSidebarNavItem(
            icon: Icons.restaurant_menu,
            label: '메뉴주문',
            isActive: _activeSidebarTab == 'menu',
            onTap: () {
              setState(() {
                _activeSidebarTab = 'menu';
              });
            },
          ),
          const SizedBox(height: 16),
          // 2. FUN (Inactive)
          _buildSidebarNavItem(
            icon: Icons.sentiment_satisfied_alt_outlined,
            label: 'FUN',
            isActive: _activeSidebarTab == 'fun',
            onTap: () {
              setState(() {
                _activeSidebarTab = 'fun';
              });
            },
          ),
          const SizedBox(height: 16),
          // 3. LANG (Inactive)
          _buildSidebarNavItem(
            icon: Icons.language,
            label: 'LANG',
            isActive: _activeSidebarTab == 'lang',
            onTap: () {
              setState(() {
                _activeSidebarTab = 'lang';
              });
            },
          ),
          const Spacer(),
          // Call Staff Button (Circle Teal)
          GestureDetector(
            onTap: () async {
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
            child: Container(
              width: 66,
              height: 66,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF007A87),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '직원\n호출',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const Text(
            'ver 3.14',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2C2E3E) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabBar(BuildContext context) {
    final tabController = DefaultTabController.of(context);
    return Container(
      color: Colors.white,
      height: 60,
      child: Row(
        children: [
          // Left Scroll Arrow
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.grey),
            onPressed: () {
              if (tabController != null && tabController.index > 0) {
                tabController.animateTo(tabController.index - 1);
              }
            },
          ),
          Expanded(
            child: TabBar(
              isScrollable: true,
              labelColor: const Color(0xFF007A87),
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              indicatorColor: const Color(0xFF007A87),
              indicatorWeight: 3.0,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: _categories.map((String name) => Tab(text: name)).toList(),
            ),
          ),
          // Right Scroll Arrow
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.grey),
            onPressed: () {
              if (tabController != null && tabController.index < _categories.length - 1) {
                tabController.animateTo(tabController.index + 1);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionBar(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 주문내역 Button
          ElevatedButton.icon(
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
            icon: const Icon(Icons.assignment_outlined, size: 20, color: Colors.grey),
            label: const Text(
              '주문내역',
              style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                side: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 주문하기 Button
          Consumer<ShoppingCart>(
            builder: (context, cart, child) {
              return ElevatedButton(
                key: KioskHomePage.cartTargetKey,
                onPressed: () {
                  setState(() {
                    _showCart = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007A87),
                  elevation: 4,
                  shadowColor: Colors.black26,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '주문하기',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Color(0xFF007A87),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
        backgroundColor: const Color(0xFFF9F9FB),
        body: Row(
          children: [
            // Left Sidebar
            _buildLeftSidebar(context),
            // Main Content Area
            Expanded(
              child: SafeArea(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeSidebarTab == 'fun'
                        ? const RouletteWidget()
                        : Stack(
                            children: [
                              Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Category Tab Bar
                              Builder(
                                builder: (tabContext) => _buildCategoryTabBar(tabContext),
                              ),
                              // Section Title & Menu Grid
                              Expanded(
                                child: _categories.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '메뉴가 없습니다. 설정에서 카테고리와 메뉴를 추가해주세요.',
                                        ),
                                      )
                                    : TabBarView(
                                        children: _categories.map((String name) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1E2022),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: MenuGrid(
                                                  items: _menuItems[name] ?? [],
                                                  imageFolderPath: _imageFolderPath != null && _imageFolderPath!.isNotEmpty
                                                      ? '$_imageFolderPath/$_restaurantName'
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                              ),
                            ],
                          ),
                          // Floating Action Buttons
                          if (!_showCart) _buildFloatingActionBar(context),
                        ],
                      ),
              ),
            ),
            // Slide-out Cart Panel
            if (_showCart)
              Container(
                width: MediaQuery.of(context).size.width * 0.45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: Colors.grey[300]!)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(-5, 0),
                    ),
                  ],
                ),
                child: _buildCartPanel(context),
              ),
          ],
        ),
      ),
    );
  }
}
