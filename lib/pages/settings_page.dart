import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/widgets/change_pin_dialog.dart';
import 'package:kiosk/pages/owner_mode_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/pages/menu_edit_page.dart';
import 'package:kiosk/widgets/custom_dialog.dart';

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
      _imageFolderPath = prefs.getString('imageFolderPath');
      _tableNumberController.text = _tableNumber;
      _restaurantNameController.text = _restaurantName;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tableNumber', _tableNumber);
    await prefs.setString('restaurantName', _restaurantName);
    // imageFolderPath is saved in _pickImageFolder
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

  void _editCategoryMenu(String categoryName) {
    if (_restaurantName.isEmpty) {
      showCustomDialog(
        context: context,
        title: '알림',
        content: '음식점 이름을 먼저 설정해주세요.',
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuEditPage(
          categoryName: categoryName,
          menuItems: _menuItems[categoryName]!,
          onUpdate: (updatedMenuItems) {
            setState(() {
              _menuItems[categoryName] = updatedMenuItems;
            });
            widget.onUpdate(_categories, _menuItems);
          },
          imageFolderPath: _imageFolderPath,
        ),
      ),
    );
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('기본 정보', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tableNumberController,
                              decoration: const InputDecoration(labelText: '테이블 번호', border: OutlineInputBorder()),
                              style: const TextStyle(fontSize: 18),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => setState(() => _tableNumber = value),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _restaurantNameController,
                              style: const TextStyle(fontSize: 18),
                              decoration: const InputDecoration(labelText: '음식점 이름', border: OutlineInputBorder()),
                              onChanged: (value) => setState(() => _restaurantName = value),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              await _saveSettings();
                              if (!mounted) return;
                              await showCustomDialog(
                                context: context,
                                title: '저장 완료',
                                content: '설정이 저장되었습니다. 메인 화면으로 돌아갑니다.',
                              );
                              if (!mounted) return;
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('이미지 폴더 설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Text('현재 설정된 폴더: ${_imageFolderPath ?? '설정되지 않음'}'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open),
                          label: const Text('이미지 폴더 선택'),
                          onPressed: _pickImageFolder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('카테고리 관리', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 8),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5, // Adjust height as needed
                  child: ReorderableListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return ListTile(
                        key: ValueKey(category),
                        title: Text(category, style: const TextStyle(fontSize: 20)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () => _editCategoryMenu(category),
                              tooltip: '메뉴 수정',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _renameCategory(index),
                              tooltip: '이름 변경',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteCategory(index),
                              tooltip: '삭제',
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
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('데이터 및 보안', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _deleteOrders(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('어제까지의 주문내역 삭제'),
                          ),
                          ElevatedButton(
                            onPressed: () => _deleteOrders(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('모든 주문 내역 삭제'),
                          ),
                          ElevatedButton(
                            onPressed: _changePin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            child: const Text('PIN 번호 변경'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
