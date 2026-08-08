import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kiosk/widgets/change_pin_dialog.dart';
import 'package:kiosk/pages/owner_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/custom_dialog.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/widgets/local_image_selector.dart';
import 'package:intl/intl.dart';

class SettingsPage extends StatefulWidget {
  final List<String> categories;
  final Map<String, List<MenuItem>> menuItems;
  final Function(List<String>, Map<String, List<MenuItem>>) onUpdate;
  final String? imageFolderPath;

  const SettingsPage({
    super.key,
    required this.categories,
    required this.menuItems,
    required this.onUpdate,
    required this.imageFolderPath,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late List<String> _categories;
  late Map<String, List<MenuItem>> _menuItems;
  late TextEditingController _tableNumberController;
  late TextEditingController _restaurantNameController;
  String _tableNumber = '';
  String _restaurantName = '';
  String? _imageFolderPath;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
    _imageFolderPath = widget.imageFolderPath;

    _menuItems = widget.menuItems.map((key, value) {
      final List<MenuItem> converted = (value as List).map<MenuItem>((item) {
        if (item is MenuItem) return item;
        return MenuItem.fromJson(Map<String, dynamic>.from(item as Map));
      }).toList();
      return MapEntry(key, converted);
    }).cast<String, List<MenuItem>>();

    _tableNumberController = TextEditingController();
    _restaurantNameController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _restaurantNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tableNumber = prefs.getString('tableNumber') ?? '';
      _restaurantName = prefs.getString('restaurantName') ?? '';
      _tableNumberController.text = _tableNumber;
      _restaurantNameController.text = _restaurantName;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tableNumber', _tableNumber);
    await prefs.setString('restaurantName', _restaurantName);
  }

  Future<void> _pickImageFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('imageFolderPath', selectedDirectory);
      setState(() {
        _imageFolderPath = selectedDirectory;
      });
    }
  }

  void _addCategory() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('새 카테고리 추가'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '카테고리 이름'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _categories.add(controller.text);
                    _menuItems[controller.text] = [];
                  });
                  widget.onUpdate(_categories, _menuItems);
                  Navigator.pop(context);
                }
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _renameCategory(int index) {
    final TextEditingController controller = TextEditingController(
      text: _categories[index],
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('카테고리 이름 변경'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final oldName = _categories[index];
                  final newName = controller.text;
                  setState(() {
                    _categories[index] = newName;
                    _menuItems[newName] = _menuItems[oldName]!;
                    _menuItems.remove(oldName);
                  });
                  widget.onUpdate(_categories, _menuItems);
                  Navigator.pop(context);
                }
              },
              child: const Text('변경'),
            ),
          ],
        );
      },
    );
  }

  void _deleteCategory(int index) {
    if (_restaurantName.isEmpty) {
      showCustomDialog(
        context: context,
        title: '알림',
        content: '음식점 이름을 먼저 설정해주세요.',
      );
      return;
    }
    final categoryName = _categories[index];
    setState(() {
      _categories.removeAt(index);
      _menuItems.remove(categoryName);
    });
    widget.onUpdate(_categories, _menuItems);
  }

  void _showMenuFormDialog(String categoryName, {MenuItem? item, int? index}) {
    final isEditing = item != null;
    final nameController = TextEditingController(
      text: isEditing ? item.name : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? item.price.toString() : '',
    );
    
    String? imageFilename = isEditing ? item.image : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? '메뉴 수정' : '새 메뉴 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: '메뉴 이름'),
                    ),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '가격'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: ImageDisplay(
                        imagePath: imageFilename,
                        imageFolderPath: _imageFolderPath,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('이미지 선택'),
                      onPressed: () async {
                        final String? selectedFilename = await showDialog<String>(
                          context: context,
                          builder: (_) => LocalImageSelector(imageFolderPath: _imageFolderPath),
                        );

                        if (selectedFilename != null) {
                          setStateDialog(() {
                            imageFilename = selectedFilename;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () {
                    if (nameController.text.isEmpty || priceController.text.isEmpty) {
                      return;
                    }

                    final newItem = MenuItem(
                      name: nameController.text,
                      image: imageFilename,
                      price: int.tryParse(priceController.text) ?? 0,
                      category: categoryName,
                    );
                    
                    setState(() {
                      if (isEditing) {
                        _menuItems[categoryName]![index!] = newItem;
                      } else {
                        if (_menuItems[categoryName] == null) {
                          _menuItems[categoryName] = [];
                        }
                        _menuItems[categoryName]!.add(newItem);
                      }
                    });

                    widget.onUpdate(_categories, _menuItems);
                    Navigator.pop(context);
                  },
                  child: Text(isEditing ? '저장' : '추가'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteMenuItem(String categoryName, int index) {
    setState(() {
      _menuItems[categoryName]!.removeAt(index);
    });
    widget.onUpdate(_categories, _menuItems);
  }

  Future<void> _changePin() async {
    final newPin = await showDialog<String>(
      context: context,
      builder: (context) => const ChangePinDialog(),
    );

    if (newPin != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('adminPin', newPin);
      showCustomDialog(
        context: context,
        title: '성공',
        content: 'PIN 번호가 변경되었습니다.',
      );
    } else {
      showCustomDialog(
        context: context,
        title: '실패',
        content: 'PIN 번호 변경에 실패했습니다. PIN 번호가 일치하지 않습니다.',
      );
    }
  }

  Future<void> _deleteOrders(bool deleteAll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(deleteAll ? '모든 주문 및 호출 내역을 삭제하시겠습니까?' : '어제까지의 주문 및 호출 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      // Delete orders
      final ordersCollection = FirebaseFirestore.instance.collection('orders');
      Query ordersQuery = ordersCollection;
      if (!deleteAll) {
        ordersQuery = ordersQuery.where('orderTime', isLessThan: Timestamp.fromDate(startOfToday));
      }
      final ordersSnapshot = await ordersQuery.get();
      for (final doc in ordersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete calls
      final callsCollection = FirebaseFirestore.instance.collection('calls');
      Query callsQuery = callsCollection;
      if (!deleteAll) {
        callsQuery = callsQuery.where('time', isLessThan: Timestamp.fromDate(startOfToday));
      }
      final callsSnapshot = await callsQuery.get();
      for (final doc in callsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      showCustomDialog(
        context: context,
        title: '삭제 완료',
        content: deleteAll ? '모든 주문 및 호출 내역이 삭제되었습니다.' : '어제까지의 주문 및 호출 내역이 삭제되었습니다.',
      );
    }
  }

  Future<void> _loadSelectedRestaurantData(String newRestaurantName) async {
    try {
      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(newRestaurantName)
          .get();

      if (restaurantDoc.exists) {
        final data = restaurantDoc.data();
        final List<String> loadedCategories = List<String>.from(data?['categories'] ?? []);
        
        final Map<String, List<MenuItem>> loadedMenuItems = {};
        final menuItemsSnapshot = await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(newRestaurantName)
            .collection('menuItems')
            .get();

        for (final cat in loadedCategories) {
          loadedMenuItems[cat] = [];
        }

        for (final doc in menuItemsSnapshot.docs) {
          final menuItem = MenuItem.fromJson(doc.data());
          final cat = menuItem.category;
          if (loadedCategories.contains(cat)) {
            loadedMenuItems[cat]!.add(menuItem);
          }
        }

        setState(() {
          _restaurantName = newRestaurantName;
          _restaurantNameController.text = newRestaurantName;
          _categories = loadedCategories;
          _menuItems = loadedMenuItems;
        });
        _saveSettings();
        widget.onUpdate(_categories, _menuItems);
      } else {
        setState(() {
          _restaurantName = newRestaurantName;
          _restaurantNameController.text = newRestaurantName;
          _categories = [];
          _menuItems = {};
        });
        _saveSettings();
        widget.onUpdate(_categories, _menuItems);
      }
    } catch (e) {
      print("Error loading restaurant data: $e");
    }
  }

  Future<void> _addNewRestaurantDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('새 매장 추가', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: '매장 이름',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF007A87))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final name = controller.text;
                await FirebaseFirestore.instance.collection('restaurants').doc(name).set({
                  'categories': [],
                });
                Navigator.pop(context);
                await _loadSelectedRestaurantData(name);
              }
            },
            child: const Text('추가', style: TextStyle(color: Color(0xFF007A87))),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRestaurant(String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('매장 삭제', style: TextStyle(color: Colors.white)),
        content: Text('$name 매장을 삭제하시겠습니까? 관련 데이터가 모두 삭제됩니다.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final restaurantRef = FirebaseFirestore.instance.collection('restaurants').doc(name);
      final menuItemsSnapshot = await restaurantRef.collection('menuItems').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in menuItemsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(restaurantRef);
      await batch.commit();

      if (_restaurantName == name) {
        setState(() {
          _restaurantName = '';
          _restaurantNameController.text = '';
          _categories = [];
          _menuItems = {};
        });
        _saveSettings();
        widget.onUpdate(_categories, _menuItems);
      }
    }
  }

  void _showRestaurantSelectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E202C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.all(20),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '매장 설정',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _addNewRestaurantDialog();
                            setDialogState(() {});
                          },
                          icon: const Icon(Icons.add, color: Colors.white, size: 16),
                          label: const Text('새 매장 추가', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007A87),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.grey, thickness: 0.5),
                    const SizedBox(height: 16),
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: const Color(0xFF12131A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2C2E3E)),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('restaurants').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return const Center(child: Text('등록된 매장이 없습니다.', style: TextStyle(color: Colors.grey)));
                          }

                          return ListView.separated(
                            itemCount: docs.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFF2C2E3E), height: 1),
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final name = doc.id;
                              final isActive = name == _restaurantName;

                              return ListTile(
                                leading: Icon(
                                  Icons.store,
                                  color: isActive ? const Color(0xFF007A87) : Colors.grey,
                                ),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                trailing: isActive
                                    ? const Icon(Icons.check, color: Color(0xFF007A87))
                                    : IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                                        onPressed: () async {
                                          await _deleteRestaurant(name);
                                          setDialogState(() {});
                                        },
                                      ),
                                onTap: () async {
                                  await _loadSelectedRestaurantData(name);
                                  setDialogState(() {});
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기', style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015), // Pitch Dark Background
      body: SafeArea(
        child: Column(
          children: [
            // Dark Header Bar
            Container(
              color: const Color(0xFF12131A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '가게 수정',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Save & Exit (저장 후 나가기)
                  GestureDetector(
                    onTap: () {
                      widget.onUpdate(_categories, _menuItems);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout, color: Color(0xFF007A87), size: 18),
                          SizedBox(width: 6),
                          Text(
                            '저장 후 나가기',
                            style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body Layout (Two Columns)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Sidebar cards)
                    SizedBox(
                      width: 320,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card 1: 기본 정보
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E202C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        '기본 정보',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      GestureDetector(
                                        onTap: _showRestaurantSelectDialog,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.edit, color: Color(0xFF007A87), size: 14),
                                            SizedBox(width: 4),
                                            Text(
                                              '변경',
                                              style: TextStyle(color: Color(0xFF007A87), fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF12131A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.store, color: Color(0xFF007A87), size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '매장 이름',
                                                style: TextStyle(color: Colors.grey, fontSize: 11),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _restaurantName,
                                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _tableNumberController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '테이블 번호',
                                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2C2E3E))),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF007A87))),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    onChanged: (value) {
                                      setState(() => _tableNumber = value);
                                      _saveSettings();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Card 2: 이미지 폴더 설정
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E202C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '이미지 폴더 설정',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF12131A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _imageFolderPath ?? '설정되지 않음',
                                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.folder_open, color: Colors.white),
                                      label: const Text('폴더 변경', style: TextStyle(color: Colors.white)),
                                      onPressed: _pickImageFolder,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF007A87),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Card 3: 보안 및 데이터
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E202C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '보안 및 데이터',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _changePin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2CA05A),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      child: const Text('PIN 번호 변경'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _deleteOrders(false),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE55A44),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      child: const Text('어제까지의 주문내역 삭제'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => _deleteOrders(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFC0222B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      child: const Text('모든 주문 내역 삭제'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Right Column (Category Reorder Management)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E202C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '카테고리 관리 (드래그 순서 변경)',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (_restaurantName.isEmpty || _tableNumber.isEmpty) {
                                      showCustomDialog(
                                        context: context,
                                        title: '알림',
                                        content: '음식점 이름과 테이블 번호를 먼저 설정해주세요.',
                                      );
                                    } else {
                                      _addCategory();
                                    }
                                  },
                                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                  label: const Text('카테고리 추가', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007A87),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _categories.isEmpty
                                  ? const Center(
                                      child: Text(
                                        '등록된 카테고리가 없습니다.',
                                        style: TextStyle(color: Colors.grey, fontSize: 16),
                                      ),
                                    )
                                  : ReorderableListView.builder(
                                      itemCount: _categories.length,
                                      onReorder: (oldIndex, newIndex) {
                                        if (_restaurantName.isEmpty) {
                                          showCustomDialog(
                                            context: context,
                                            title: '알림',
                                            content: '음식점 이름과 테이블 번호를 먼저 설정해주세요.',
                                          );
                                          return;
                                        }
                                        setState(() {
                                          if (newIndex > oldIndex) newIndex -= 1;
                                          final String item = _categories.removeAt(oldIndex);
                                          _categories.insert(newIndex, item);
                                        });
                                        widget.onUpdate(_categories, _menuItems);
                                      },
                                      itemBuilder: (context, index) {
                                        final category = _categories[index];
                                        final items = _menuItems[category] ?? [];
                                        final currencyFormat = NumberFormat('#,##0', 'ko_KR');

                                        return Card(
                                          key: ValueKey(category),
                                          color: const Color(0xFF222530),
                                          margin: const EdgeInsets.symmetric(vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Theme(
                                            data: Theme.of(context).copyWith(
                                              dividerColor: Colors.transparent,
                                              unselectedWidgetColor: Colors.grey,
                                            ),
                                            child: ExpansionTile(
                                              iconColor: Colors.white,
                                              collapsedIconColor: Colors.grey,
                                              title: Text(
                                                category,
                                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                                                    onPressed: () => _renameCategory(index),
                                                    tooltip: '이름 변경',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                    onPressed: () => _deleteCategory(index),
                                                    tooltip: '삭제',
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ReorderableDragStartListener(
                                                    index: index,
                                                    child: const Icon(Icons.menu, color: Colors.grey, size: 20),
                                                  ),
                                                ],
                                              ),
                                              children: [
                                                ...items.asMap().entries.map((entry) {
                                                  final itemIndex = entry.key;
                                                  final item = entry.value;
                                                  return Container(
                                                    color: const Color(0xFF1E202C),
                                                    child: ListTile(
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                                      leading: SizedBox(
                                                        width: 40,
                                                        height: 40,
                                                        child: ImageDisplay(
                                                          imagePath: item.image,
                                                          imageFolderPath: _imageFolderPath,
                                                        ),
                                                      ),
                                                      title: Text(item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                                      subtitle: Text('${currencyFormat.format(item.price)}원', style: const TextStyle(color: Colors.grey)),
                                                      trailing: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 18),
                                                            onPressed: () => _showMenuFormDialog(category, item: item, index: itemIndex),
                                                            tooltip: '메뉴 수정',
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                            onPressed: () => _deleteMenuItem(category, itemIndex),
                                                            tooltip: '메뉴 삭제',
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }),
                                                Container(
                                                  color: const Color(0xFF1E202C),
                                                  child: ListTile(
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                                    leading: const Icon(Icons.add, color: Color(0xFF007A87)),
                                                    title: const Text('메뉴 추가', style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
                                                    onTap: () => _showMenuFormDialog(category),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
