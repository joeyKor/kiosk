import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:image_cropper/image_cropper.dart' as image_cropper;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosk/menu_item_dialog.dart';
import 'package:provider/provider.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/pages/settings_page.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/menu_grid.dart';
import 'package:kiosk/shopping_cart_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(
      ChangeNotifierProvider(
        create: (context) => ShoppingCart(),
        child: const MyApp(),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tableNumber = prefs.getString('tableNumber') ?? '';
      _restaurantName = prefs.getString('restaurantName') ?? '';
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _categories = prefs.getStringList('categories') ?? [];
      final String? menuItemsString = prefs.getString('menuItems');
      if (menuItemsString != null) {
        final Map<String, dynamic> decodedMap = jsonDecode(menuItemsString);
        _menuItems = decodedMap.map((key, value) {
          final List<MenuItem> items = (value as List)
              .map((item) => MenuItem.fromJson(item as Map<String, dynamic>))
              .toList();
          return MapEntry(key, items);
        });
      }
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('categories', _categories);
    final String encodedMap = jsonEncode(
      _menuItems.map(
        (key, value) =>
            MapEntry(key, value.map((item) => item.toJson()).toList()),
      ),
    );
    await prefs.setString('menuItems', encodedMap);
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

  @override
  Widget build(BuildContext context) {
    // Rebuild the DefaultTabController whenever the number of categories changes.
    return DefaultTabController(
      key: ValueKey(_categories.length),
      length: _categories.length,
      child: Scaffold(
        body: SafeArea(
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
                        Row(
                          children: [
                            if (_tableNumber.isNotEmpty)
                              Text(
                                '테이블: $_tableNumber',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              onPressed: () {
                                // TODO: Implement staff call logic
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[800],
                              ),
                              child: const Text(
                                '직원호출',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(
                                  categories: _categories,
                                  menuItems: _menuItems,
                                  onUpdate: _updateCategoriesAndMenus,
                                ),
                              ),
                            );
                            _loadSettings(); // Reload settings after returning from SettingsPage
                          },
                        ),
                      ],
                    ),
                    Expanded(
                      child: _categories.isEmpty
                          ? const Center(
                              child: Text(
                                  '메뉴가 없습니다. 설정에서 카테고리와 메뉴를 추가해주세요.'),
                            )
                          : TabBarView(
                              children: _categories.map((String name) {
                                return MenuGrid(items: _menuItems[name] ?? []);
                              }).toList(),
                            ),
                    ),
                  ],
                ),
        ),
        floatingActionButton: Consumer<ShoppingCart>(
          builder: (context, cart, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: null, // Disabled
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Padding(
                    padding:
                        EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Text(
                      '주문내역',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ShoppingCartPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '주문하기',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
