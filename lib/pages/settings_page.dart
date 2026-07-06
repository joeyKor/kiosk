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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontSize: 24)),
        actions: [
          TextButton.icon(
            onPressed: () {
              if (_restaurantName.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OwnerModePage(restaurantName: _restaurantName),
                  ),
                );
              } else {
                showCustomDialog(
                  context: context,
                  title: '알림',
                  content: '음식점 이름을 먼저 설정해주세요.',
                );
              }
            },
            icon: const Icon(Icons.store, color: Colors.white),
            label: const Text(
              '가게 모드',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Basic Info, Image Folder, Security & Data
            SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card 1: Basic Info
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('기본 정보 (자동 저장)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _tableNumberController,
                              decoration: const InputDecoration(labelText: '테이블 번호', border: OutlineInputBorder()),
                              style: const TextStyle(fontSize: 18),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() => _tableNumber = value);
                                _saveSettings();
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _restaurantNameController,
                              style: const TextStyle(fontSize: 18),
                              decoration: const InputDecoration(labelText: '음식점 이름', border: OutlineInputBorder()),
                              onChanged: (value) {
                                setState(() => _restaurantName = value);
                                _saveSettings();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Card 2: Image Folder
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('이미지 폴더 설정', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(
                              '현재 폴더: ${_imageFolderPath ?? "설정되지 않음"}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.folder_open),
                                label: const Text('폴더 변경'),
                                onPressed: _pickImageFolder,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  textStyle: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Card 3: Security & Clean Up
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('보안 및 데이터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _changePin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                  backgroundColor: Colors.red[400],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                child: const Text('모든 주문 내역 삭제'),
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
            const SizedBox(width: 20),
            // Right Column: Category Management
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('카테고리 관리 (드래그하여 순서 변경)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('카테고리 추가'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _categories.isEmpty
                            ? const Center(
                                child: Text('등록된 카테고리가 없습니다.', style: TextStyle(fontSize: 16)),
                              )
                            : ReorderableListView.builder(
                                itemCount: _categories.length,
                                itemBuilder: (context, index) {
                                  final category = _categories[index];
                                  final items = _menuItems[category] ?? [];
                                  final currencyFormat = NumberFormat('#,##0', 'ko_KR');
                                  
                                  return Card(
                                    key: ValueKey(category),
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey[200]!),
                                    ),
                                    child: ExpansionTile(
                                      title: Text(category, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.orange),
                                            onPressed: () => _renameCategory(index),
                                            tooltip: '이름 변경',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteCategory(index),
                                            tooltip: '삭제',
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.drag_handle, color: Colors.grey),
                                        ],
                                      ),
                                      children: [
                                        ...items.asMap().entries.map((entry) {
                                          final itemIndex = entry.key;
                                          final item = entry.value;
                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                                            leading: SizedBox(
                                              width: 40,
                                              height: 40,
                                              child: ImageDisplay(
                                                imagePath: item.image,
                                                imageFolderPath: _imageFolderPath,
                                              ),
                                            ),
                                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                                            subtitle: Text('${currencyFormat.format(item.price)}원'),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
                                                  onPressed: () => _showMenuFormDialog(category, item: item, index: itemIndex),
                                                  tooltip: '메뉴 수정',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                  onPressed: () => _deleteMenuItem(category, itemIndex),
                                                  tooltip: '메뉴 삭제',
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                        ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                                          leading: const Icon(Icons.add, color: Colors.blue),
                                          title: const Text('메뉴 추가', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                          onTap: () => _showMenuFormDialog(category),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onReorder: (oldIndex, newIndex) {
                                  if (_restaurantName.isEmpty) {
                                    showCustomDialog(
                                      context: context,
                                      title: '알림',
                                      content: '음식점 이름을 먼저 설정해주세요.',
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
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
