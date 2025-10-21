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

  const SettingsPage({
    super.key,
    required this.categories,
    required this.menuItems,
    required this.onUpdate,
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

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);

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
    final categoryName = _categories[index];
    setState(() {
      _categories.removeAt(index);
      _menuItems.remove(categoryName);
    });
    widget.onUpdate(_categories, _menuItems);
  }

  void _editCategoryMenu(String categoryName) {
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
        ),
      ),
    );
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
                            onPressed: () {
                              _saveSettings();
                              showCustomDialog(
                                context: context,
                                title: '저장 완료',
                                content: '설정이 저장되었습니다.',
                              );
                            },
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                            child: const Text('저장'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('카테고리 관리', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
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
        tooltip: '카테고리 추가',
        child: const Icon(Icons.add),
      ),
    );
  }
}
