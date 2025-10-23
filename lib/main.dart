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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

  @override
  Widget build(BuildContext context) {
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
            Container(
              width: 220,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(left: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
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
                            builder: (context) =>
                                PinDialog(correctPin: adminPin),
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
                      if (_restaurantName.isNotEmpty &&
                          _tableNumber.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('calls')
                            .add({
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
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ShoppingCartPage(
                                        restaurantName: _restaurantName,
                                        tableNumber: _tableNumber,
                                        imageFolderPath: _imageFolderPath,
                                      )),
                            );
                            _checkOrderHistory();
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
