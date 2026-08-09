import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiosk/widgets/image_crop_screen.dart';
import 'package:kiosk/widgets/change_pin_dialog.dart';
import 'package:kiosk/widgets/pin_dialog.dart';
import 'package:kiosk/pages/owner_mode_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  final Function(String, List<String>, Map<String, List<MenuItem>>) onUpdate;
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
  String? _selectedCategory;

  String? get _currentStoreImageFolderPath {
    if (_imageFolderPath == null || _imageFolderPath!.isEmpty) return null;
    if (_restaurantName.isEmpty) return _imageFolderPath;
    return '$_imageFolderPath/$_restaurantName';
  }

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

    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }
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
    if (_restaurantName == '조이김밥') {
      showCustomDialog(
        context: context,
        title: '변경 불가',
        content: '기본 설정 매장 [조이김밥]의 카테고리는 추가할 수 없습니다.',
      );
      return;
    }
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
                    _selectedCategory ??= controller.text;
                  });
                  widget.onUpdate(_restaurantName, _categories, _menuItems);
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
    if (_restaurantName == '조이김밥') {
      showCustomDialog(
        context: context,
        title: '변경 불가',
        content: '기본 설정 매장 [조이김밥]의 카테고리는 수정할 수 없습니다.',
      );
      return;
    }
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
                    final items = _menuItems[oldName];
                    if (items != null) {
                      for (final item in items) {
                        item.category = newName;
                      }
                      _menuItems[newName] = items;
                    } else {
                      _menuItems[newName] = [];
                    }
                    _menuItems.remove(oldName);
                    if (_selectedCategory == oldName) {
                      _selectedCategory = newName;
                    }
                  });
                  widget.onUpdate(_restaurantName, _categories, _menuItems);
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

  Future<void> _deleteCategory(int index) async {
    if (_restaurantName == '조이김밥') {
      showCustomDialog(
        context: context,
        title: '변경 불가',
        content: '기본 설정 매장 [조이김밥]의 카테고리는 삭제할 수 없습니다.',
      );
      return;
    }
    if (_restaurantName.isEmpty) {
      showCustomDialog(
        context: context,
        title: '알림',
        content: '음식점 이름을 먼저 설정해주세요.',
      );
      return;
    }
    final categoryName = _categories[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('카테고리 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('[$categoryName] 카테고리를 삭제하시겠습니까?\n카테고리 안의 모든 메뉴 데이터도 함께 영구 삭제되며 복구할 수 없습니다.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _categories.removeAt(index);
      _menuItems.remove(categoryName);
      if (_selectedCategory == categoryName) {
        _selectedCategory = _categories.isNotEmpty ? _categories.first : null;
      }
    });
    widget.onUpdate(_restaurantName, _categories, _menuItems);
  }

  void _showMenuFormDialog(String categoryName, {MenuItem? item, int? index}) {
    if (_restaurantName == '조이김밥') {
      showCustomDialog(
        context: context,
        title: '변경 불가',
        content: '기본 설정 매장 [조이김밥]의 메뉴는 수정할 수 없습니다.',
      );
      return;
    }
    final isEditing = item != null;
    final nameController = TextEditingController(
      text: isEditing ? item.name : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? item.price.toString() : '',
    );
    final descriptionController = TextEditingController(
      text: isEditing ? (item.description ?? '') : '',
    );
    
    bool isBest = isEditing ? item.isBest : false;
    bool isNew = isEditing ? item.isNew : false;
    String? imageFilename = isEditing ? item.image : null;
    Uint8List? localCroppedBytes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: const Color(0xFF1E222B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 480,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? '메뉴 수정' : '새 메뉴 추가',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Menu Name Field
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '메뉴 이름',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF007A87)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Price Field
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '가격 (원)',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF007A87)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: '메뉴 설명',
                        labelStyle: const TextStyle(color: Colors.white70),
                        alignLabelWithHint: true,
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF007A87)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tags Settings
                    Row(
                      children: [
                        const Text(
                          '태그 설정: ',
                          style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              isBest = !isBest;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isBest ? const Color(0xFF007A87) : Colors.transparent,
                              border: Border.all(color: isBest ? Colors.transparent : Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BEST',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setStateDialog(() {
                              isNew = !isNew;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isNew ? const Color(0xFF007A87) : Colors.transparent,
                              border: Border.all(color: isNew ? Colors.transparent : Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Menu Image Selection
                    const Text(
                      '메뉴 이미지',
                      style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Image Preview Box
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: localCroppedBytes != null
                                ? Image.memory(
                                    localCroppedBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : ImageDisplay(
                                    imagePath: imageFilename,
                                    imageFolderPath: _currentStoreImageFolderPath,
                                    itemName: nameController.text.trim().isEmpty ? null : nameController.text.trim(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Choose Image Button
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007A87),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.image_search),
                              label: const Text('이미지 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                if (nameController.text.trim().isEmpty) {
                                  showCustomDialog(
                                    context: context,
                                    title: '알림',
                                    content: '이미지를 선택하기 전에 메뉴 이름을 먼저 입력해주세요.',
                                  );
                                  return;
                                }

                                if (_imageFolderPath == null || _imageFolderPath!.isEmpty) {
                                  showCustomDialog(
                                    context: context,
                                    title: '폴더 미설정',
                                    content: '먼저 프로그램 설정에서 이미지 폴더를 지정해주세요.',
                                  );
                                  return;
                                }

                                final ImageSource? source = await showDialog<ImageSource>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E202C),
                                    title: const Text('이미지 선택', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    content: const Text('이미지를 가져올 방법을 선택하세요.', style: TextStyle(color: Colors.grey)),
                                    actions: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.camera_alt, color: Color(0xFF007A87)),
                                        label: const Text('카메라', style: TextStyle(color: Colors.white)),
                                        onPressed: () => Navigator.pop(context, ImageSource.camera),
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.photo_library, color: Color(0xFF007A87)),
                                        label: const Text('갤러리', style: TextStyle(color: Colors.white)),
                                        onPressed: () => Navigator.pop(context, ImageSource.gallery),
                                      ),
                                    ],
                                  ),
                                );

                                if (source != null) {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? pickedFile = await picker.pickImage(source: source);
                                  if (pickedFile != null) {
                                    final Uint8List? croppedBytes = await Navigator.push<Uint8List>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ImageCropScreen(file: pickedFile),
                                      ),
                                    );

                                    if (croppedBytes != null) {
                                      final menuName = nameController.text.trim().replaceAll('/', '_').replaceAll('.', '_');
                                      final fileName = '$menuName.png';
                                      if (!kIsWeb) {
                                        final targetDir = _currentStoreImageFolderPath;
                                        if (targetDir != null) {
                                          final directory = Directory(targetDir);
                                          if (!await directory.exists()) {
                                            await directory.create(recursive: true);
                                          }
                                          final file = File('$targetDir/$fileName');
                                          await file.writeAsBytes(croppedBytes);
                                        }
                                      }

                                      setStateDialog(() {
                                        imageFilename = fileName;
                                        localCroppedBytes = croppedBytes;
                                      });
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Action Cancel/Save Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                foregroundColor: Colors.white70,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007A87),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                if (nameController.text.isEmpty || priceController.text.isEmpty) {
                                  return;
                                }

                                final newItem = MenuItem(
                                  name: nameController.text,
                                  image: imageFilename,
                                  price: int.tryParse(priceController.text) ?? 0,
                                  category: categoryName,
                                  description: descriptionController.text,
                                  isBest: isBest,
                                  isNew: isNew,
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

                                PaintingBinding.instance.imageCache.clear();
                                PaintingBinding.instance.imageCache.clearLiveImages();
                                widget.onUpdate(_restaurantName, _categories, _menuItems);
                                Navigator.pop(context);
                              },
                              child: Text(isEditing ? '저장' : '추가', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
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

  void _deleteMenuItem(String categoryName, int index) {
    setState(() {
      _menuItems[categoryName]!.removeAt(index);
    });
    widget.onUpdate(_restaurantName, _categories, _menuItems);
  }

  Future<void> _loadSelectedRestaurantData(String newRestaurantName) async {
    try {
      final restaurantDoc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(newRestaurantName)
          .get();

      List<String> loadedCategories = [];
      if (restaurantDoc.exists && restaurantDoc.data() != null && restaurantDoc.data()!.containsKey('categories')) {
        loadedCategories = List<String>.from(restaurantDoc.data()!['categories'] ?? []);
      }

      if (loadedCategories.isEmpty && newRestaurantName == '조이김밥') {
        loadedCategories = ['김밥', '분식', '음료'];
        await FirebaseFirestore.instance
            .collection('restaurants')
            .doc(newRestaurantName)
            .set({'categories': loadedCategories}, SetOptions(merge: true));
      }

      final Map<String, List<MenuItem>> loadedMenuItems = {};
      for (final cat in loadedCategories) {
        loadedMenuItems[cat] = [];
      }

      final menuItemsSnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(newRestaurantName)
          .collection('menuItems')
          .get();

      for (final doc in menuItemsSnapshot.docs) {
        final menuItem = MenuItem.fromJson(doc.data());
        final cat = menuItem.category;
        if (!loadedMenuItems.containsKey(cat)) {
          loadedMenuItems[cat] = [];
        }
        loadedMenuItems[cat]!.add(menuItem);
      }

      setState(() {
        _restaurantName = newRestaurantName;
        _restaurantNameController.text = newRestaurantName;
        _categories = loadedCategories;
        _menuItems = loadedMenuItems;
        _selectedCategory = loadedCategories.isNotEmpty ? loadedCategories.first : null;
      });
      await _saveSettings();
      widget.onUpdate(_restaurantName, _categories, _menuItems);
    } catch (e) {
      print("Error loading restaurant data: $e");
    }
  }

  Future<void> _addNewRestaurantDialog() async {
    final nameController = TextEditingController();
    final pinController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('새 매장 추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '매장 이름',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF007A87))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                counterText: '',
                labelText: '매장 PIN 번호 (숫자 4자리)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF007A87))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim().replaceAll('/', '_').replaceAll('.', '_');
              final pin = pinController.text.trim();

              if (name.isEmpty) return;
              if (pin.length != 4) {
                showCustomDialog(
                  context: context,
                  title: '입력 오류',
                  content: '매장 PIN 번호는 숫자 4자리로 설정해주세요.',
                );
                return;
              }

              await FirebaseFirestore.instance.collection('restaurants').doc(name).set({
                'categories': [],
                'pin': pin,
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              Navigator.pop(context);
              await _loadSelectedRestaurantData(name);
            },
            child: const Text('추가', style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRestaurant(String name) async {
    if (name == '조이김밥') {
      showCustomDialog(
        context: context,
        title: '삭제 불가',
        content: '기본 매장인 [조이김밥]은 삭제할 수 없습니다.',
      );
      return;
    }

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
          _selectedCategory = null;
        });
        _saveSettings();
        widget.onUpdate(_restaurantName, _categories, _menuItems);
      }
    }
  }

  Future<bool> _verifyRestaurantPassword(String restaurantName, String actionTitle) async {
    return await StorePinDialog.show(
      context,
      restaurantName: restaurantName,
      actionTitle: actionTitle,
    );
  }

  Future<void> _clearStoreOrdersAndCalls() async {
    if (_restaurantName.isEmpty) {
      showCustomDialog(
        context: context,
        title: '알림',
        content: '음식점 이름을 먼저 설정해주세요.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('기록 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('[$_restaurantName] 매장의 모든 주문 내역과 직원 호출 기록을 영구히 삭제하시겠습니까?\n이 작업은 복구할 수 없습니다.', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF007A87)),
      ),
    );

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Fetch and delete orders
      final ordersSnapshot = await db
          .collection('orders')
          .where('restaurantName', isEqualTo: _restaurantName)
          .get();
      for (final doc in ordersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 2. Fetch and delete calls
      final callsSnapshot = await db
          .collection('calls')
          .where('restaurantName', isEqualTo: _restaurantName)
          .get();
      for (final doc in callsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context); // Pop the progress indicator
        showCustomDialog(
          context: context,
          title: '삭제 완료',
          content: '[$_restaurantName] 매장의 모든 주문 및 호출 기록이 삭제되었습니다.',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop the progress indicator
        showCustomDialog(
          context: context,
          title: '오류',
          content: '기록을 삭제하는 동안 오류가 발생했습니다: $e',
        );
      }
    }
  }

  Future<void> _showImageCopyDialog() async {
    if (_restaurantName.isEmpty) {
      showCustomDialog(
        context: context,
        title: '알림',
        content: '음식점 이름을 먼저 설정해주세요.',
      );
      return;
    }

    if (kIsWeb) {
      showCustomDialog(
        context: context,
        title: '지원되지 않음',
        content: '웹 브라우저 환경에서는 로컬 폴더 직접 복사 기능(가져오기/내보내기)을 지원하지 않습니다. PC 설치형 앱을 이용해주세요.',
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('이미지 파일 복사', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          '메뉴 이미지 폴더의 데이터를 가져오거나 USB 등으로 내보낼 수 있습니다.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007A87),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _importImageFolder();
                    },
                    icon: const Icon(Icons.file_download, color: Colors.white),
                    label: const Text('가져오기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE55A44),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _exportImageFolder();
                    },
                    icon: const Icon(Icons.file_upload, color: Colors.white),
                    label: const Text('내보내기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportImageFolder() async {
    final sourcePath = _currentStoreImageFolderPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      showCustomDialog(
        context: context,
        title: '폴더 미설정',
        content: '현재 매장 이미지 폴더 경로를 찾을 수 없습니다.',
      );
      return;
    }

    final sourceDir = Directory(sourcePath);
    if (!await sourceDir.exists()) {
      showCustomDialog(
        context: context,
        title: '알림',
        content: '내보낼 이미지가 존재하지 않습니다. (폴더가 생성되지 않음)',
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('내보내기 안내', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '현재 매장의 이미지 폴더([$sourcePath])의 데이터를 통째로 복사합니다.\n이어서 열리는 선택창에서는 저장할 대상 위치(USB 드라이브 등)를 선택해 주세요.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('대상 폴더 선택', style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    final targetPath = await FilePicker.platform.getDirectoryPath();
    if (targetPath == null || targetPath.isEmpty) return;

    if (targetPath == '/' || targetPath == '//' || targetPath.startsWith('//') || targetPath.startsWith('\\\\')) {
      showCustomDialog(
        context: context,
        title: '경로 오류',
        content: '시스템 루트 디렉토리(/)나 빈 경로에는 저장할 수 없습니다. 쓰기 가능한 USB 드라이브 내부의 폴더나 다른 하위 폴더를 선택해 주세요.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF007A87)),
      ),
    );

    try {
      final exportDestPath = '$targetPath/$_restaurantName'.replaceAll('//', '/');
      final targetDir = Directory(exportDestPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int fileCount = 0;
      await for (final entity in sourceDir.list(recursive: false)) {
        if (entity is File) {
          final fileName = entity.path.split(Platform.pathSeparator).last;
          final destFile = File('$exportDestPath/$fileName');
          await entity.copy(destFile.path);
          fileCount++;
        }
      }

      if (mounted) Navigator.pop(context);

      showCustomDialog(
        context: context,
        title: '내보내기 완료',
        content: '총 $fileCount개의 이미지 파일을\n[$exportDestPath] 폴더로 복사 완료했습니다.',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      
      String errorContent = '파일을 내보내는 중 오류가 발생했습니다: $e';
      final errStr = e.toString();
      if (errStr.contains('Read-only') || errStr.contains('errno = 30') || errStr.contains('permission') || errStr.contains('errno = 13')) {
        errorContent = '선택하신 저장 공간이 읽기 전용(Read-only) 상태이거나 권한이 부족하여 쓸 수 없습니다. 쓰기 권한이 허용된 다른 USB 폴더나 경로를 선택해 주세요.';
      }
      
      showCustomDialog(
        context: context,
        title: '오류',
        content: errorContent,
      );
    }
  }

  Future<void> _importImageFolder() async {
    final destPath = _currentStoreImageFolderPath;
    if (destPath == null || destPath.isEmpty) {
      showCustomDialog(
        context: context,
        title: '폴더 미설정',
        content: '현재 매장 이미지 폴더 경로를 설정할 수 없습니다.',
      );
      return;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('가져오기 안내', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '외부(USB 등) 이미지 폴더의 데이터를 가져와 현재 매장 폴더([$destPath])에 덮어씁니다.\n이어서 열리는 선택창에서 이미지들이 들어있는 원본 폴더를 선택해 주세요.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('원본 폴더 선택', style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    final sourcePath = await FilePicker.platform.getDirectoryPath();
    if (sourcePath == null || sourcePath.isEmpty) return;

    if (sourcePath == '/' || sourcePath == '//' || sourcePath.startsWith('//') || sourcePath.startsWith('\\\\')) {
      showCustomDialog(
        context: context,
        title: '경로 오류',
        content: '시스템 루트 디렉토리(/)는 가져오기 경로로 사용할 수 없습니다. 이미지 파일들이 들어있는 올바른 폴더를 선택해 주세요.',
      );
      return;
    }

    final sourceDir = Directory(sourcePath);
    if (!await sourceDir.exists()) {
      showCustomDialog(
        context: context,
        title: '오류',
        content: '선택하신 가져오기 폴더가 유효하지 않습니다.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF007A87)),
      ),
    );

    try {
      final destDir = Directory(destPath);
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      int fileCount = 0;
      final supportedExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'];

      await for (final entity in sourceDir.list(recursive: false)) {
        if (entity is File) {
          final filePath = entity.path.toLowerCase();
          final hasValidExtension = supportedExtensions.any((ext) => filePath.endsWith(ext));
          
          if (hasValidExtension) {
            final fileName = entity.path.split(Platform.pathSeparator).last;
            final destFile = File('$destPath/$fileName');
            await entity.copy(destFile.path);
            fileCount++;
          }
        }
      }

      if (mounted) Navigator.pop(context);

      showCustomDialog(
        context: context,
        title: '가져오기 완료',
        content: '총 $fileCount개의 이미지 파일을\n[$destPath] 매장 이미지 폴더로 복사 완료했습니다.',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      
      String errorContent = '파일을 가져오는 중 오류가 발생했습니다: $e';
      final errStr = e.toString();
      if (errStr.contains('Read-only') || errStr.contains('errno = 30') || errStr.contains('permission') || errStr.contains('errno = 13')) {
        errorContent = '지정된 가져오기/쓰기 경로에 권한이 부족하거나 대상 폴더가 읽기 전용 상태입니다. 매장 설정 폴더 쓰기 권한이 허용되어 있는지 확인해 주세요.';
      }
      
      showCustomDialog(
        context: context,
        title: '오류',
        content: errorContent,
      );
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
                                    : (name == '조이김밥'
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                                            onPressed: () async {
                                              final verified = await _verifyRestaurantPassword(name, '삭제');
                                              if (verified) {
                                                await _deleteRestaurant(name);
                                                setDialogState(() {});
                                              }
                                            },
                                          )),
                                onTap: () async {
                                  if (name == _restaurantName) return;
                                  final verified = await _verifyRestaurantPassword(name, '변경');
                                  if (verified) {
                                    await _loadSelectedRestaurantData(name);
                                    setDialogState(() {});
                                  }
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
                    '매장 관리',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Save & Exit (저장 후 나가기)
                  GestureDetector(
                    onTap: () async {
                      _tableNumber = _tableNumberController.text.trim();
                      await _saveSettings();
                      widget.onUpdate(_restaurantName, _categories, _menuItems);
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
            if (_restaurantName == '조이김밥')
              Container(
                width: double.infinity,
                color: const Color(0xFFC0222B),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '기본 설정 매장 [조이김밥]은 카테고리/메뉴 추가, 수정, 삭제가 불가능합니다. 임의 편집을 원하시면 좌측 상단의 [매장 설정]을 통해 새 매장을 추가한 뒤 편집해주세요.',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            // Body Layout (Two Columns: Left categories sidebar, Right menus details)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (Sidebar cards - Basic settings & Category Management)
                    SizedBox(
                      width: 340,
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
                                      '기본 정보 설정',
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
                                            '매장 설정',
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
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _tableNumberController,
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    labelText: '테이블 번호',
                                    labelStyle: const TextStyle(color: Colors.grey),
                                    prefixIcon: const Icon(Icons.tag, color: Color(0xFF007A87)),
                                    filled: true,
                                    fillColor: const Color(0xFF12131A),
                                    enabledBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFF2C2E3E)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: const BorderSide(color: Color(0xFF007A87)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC0222B),
                                    minimumSize: const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _clearStoreOrdersAndCalls,
                                  icon: const Icon(Icons.delete_sweep, color: Colors.white, size: 18),
                                  label: const Text(
                                    '매장 주문/호출 내역 삭제',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007A87),
                                    minimumSize: const Size(double.infinity, 44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _showImageCopyDialog,
                                  icon: const Icon(Icons.copy_all, color: Colors.white, size: 18),
                                  label: const Text(
                                    '이미지파일 복사',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Card 2: 카테고리 관리
                          Expanded(
                            child: Container(
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
                                        '카테고리 관리',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add, color: _restaurantName == '조이김밥' ? Colors.grey : const Color(0xFF007A87), size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          if (_restaurantName == '조이김밥') {
                                            showCustomDialog(
                                              context: context,
                                              title: '변경 불가',
                                              content: '기본 설정 매장 [조이김밥]의 카테고리는 추가할 수 없습니다.',
                                            );
                                            return;
                                          }
                                          if (_restaurantName.isEmpty) {
                                            showCustomDialog(
                                              context: context,
                                              title: '알림',
                                              content: '음식점 이름을 먼저 설정해주세요.',
                                            );
                                          } else {
                                            _addCategory();
                                          }
                                        },
                                        tooltip: '카테고리 추가',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    '드래그하여 순서를 변경하고, 카테고리를 클릭하면 우측에 메뉴가 나타납니다.',
                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: _categories.isEmpty
                                        ? const Center(
                                            child: Text(
                                              '등록된 카테고리가 없습니다.',
                                              style: TextStyle(color: Colors.grey, fontSize: 13),
                                            ),
                                          )
                                        : ReorderableListView.builder(
                                            itemCount: _categories.length,
                                            onReorder: (oldIndex, newIndex) {
                                              if (_restaurantName == '조이김밥') {
                                                showCustomDialog(
                                                  context: context,
                                                  title: '변경 불가',
                                                  content: '기본 설정 매장 [조이김밥]의 카테고리 순서는 변경할 수 없습니다.',
                                                );
                                                return;
                                              }
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
                                              widget.onUpdate(_restaurantName, _categories, _menuItems);
                                            },
                                            itemBuilder: (context, index) {
                                              final category = _categories[index];
                                              final isSelected = category == _selectedCategory;

                                              return Card(
                                                key: ValueKey(category),
                                                color: isSelected ? const Color(0xFF007A87) : const Color(0xFF222530),
                                                margin: const EdgeInsets.symmetric(vertical: 4),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: ListTile(
                                                  dense: true,
                                                  contentPadding: const EdgeInsets.only(left: 12, right: 4),
                                                  title: Text(
                                                    category,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedCategory = category;
                                                    });
                                                  },
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(Icons.edit_outlined, color: _restaurantName == '조이김밥' ? Colors.grey : Colors.orange, size: 16),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () {
                                                          if (_restaurantName == '조이김밥') {
                                                            showCustomDialog(
                                                              context: context,
                                                              title: '변경 불가',
                                                              content: '기본 설정 매장 [조이김밥]의 카테고리는 수정할 수 없습니다.',
                                                            );
                                                            return;
                                                          }
                                                          _renameCategory(index);
                                                        },
                                                        tooltip: '이름 변경',
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: Icon(Icons.delete_outline, color: _restaurantName == '조이김밥' ? Colors.grey : Colors.red, size: 16),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () {
                                                          if (_restaurantName == '조이김밥') {
                                                            showCustomDialog(
                                                              context: context,
                                                              title: '변경 불가',
                                                              content: '기본 설정 매장 [조이김밥]의 카테고리는 삭제할 수 없습니다.',
                                                            );
                                                            return;
                                                          }
                                                          _deleteCategory(index);
                                                        },
                                                        tooltip: '삭제',
                                                      ),
                                                      const SizedBox(width: 4),
                                                      ReorderableDragStartListener(
                                                        index: index,
                                                        child: const Icon(Icons.menu, color: Colors.grey, size: 16),
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
                    const SizedBox(width: 20),
                    // Right Column (Menu Items inside Selected Category)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E202C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _selectedCategory == null
                            ? const Center(
                                child: Text(
                                  '카테고리를 먼저 추가하거나 선택해주세요.',
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '[$_selectedCategory] 메뉴 관리',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (_restaurantName == '조이김밥') {
                                            showCustomDialog(
                                              context: context,
                                              title: '변경 불가',
                                              content: '기본 설정 매장 [조이김밥]에는 메뉴를 추가할 수 없습니다. 새 매장을 등록한 후 편집해주세요.',
                                            );
                                            return;
                                          }
                                          _showMenuFormDialog(_selectedCategory!);
                                        },
                                        icon: const Icon(Icons.add, color: Colors.white, size: 16),
                                        label: const Text('메뉴 추가', style: TextStyle(color: Colors.white)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _restaurantName == '조이김밥' ? Colors.grey : const Color(0xFF007A87),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: (_menuItems[_selectedCategory] == null || _menuItems[_selectedCategory]!.isEmpty)
                                        ? const Center(
                                            child: Text(
                                              '이 카테고리에 등록된 메뉴가 없습니다.',
                                              style: TextStyle(color: Colors.grey, fontSize: 16),
                                            ),
                                          )
                                        : ListView.builder(
                                            itemCount: _menuItems[_selectedCategory]!.length,
                                            itemBuilder: (context, index) {
                                              final item = _menuItems[_selectedCategory]![index];
                                              final currencyFormat = NumberFormat('#,##0', 'ko_KR');

                                              return Card(
                                                color: const Color(0xFF222530),
                                                margin: const EdgeInsets.symmetric(vertical: 6),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: ListTile(
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  leading: SizedBox(
                                                    width: 50,
                                                    height: 50,
                                                    child: ImageDisplay(
                                                      imagePath: item.image,
                                                      imageFolderPath: _currentStoreImageFolderPath,
                                                    ),
                                                  ),
                                                  title: Text(
                                                    item.name,
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '${currencyFormat.format(item.price)}원',
                                                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                                                      ),
                                                      if (item.description != null && item.description!.isNotEmpty)
                                                        const SizedBox(height: 4),
                                                      if (item.description != null && item.description!.isNotEmpty)
                                                        Text(
                                                          item.description!,
                                                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                  trailing: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(Icons.edit_outlined, color: _restaurantName == '조이김밥' ? Colors.grey : Colors.orange, size: 20),
                                                        onPressed: () {
                                                          if (_restaurantName == '조이김밥') {
                                                            showCustomDialog(
                                                              context: context,
                                                              title: '변경 불가',
                                                              content: '기본 설정 매장 [조이김밥]의 메뉴는 수정할 수 없습니다.',
                                                            );
                                                            return;
                                                          }
                                                          _showMenuFormDialog(_selectedCategory!, item: item, index: index);
                                                        },
                                                        tooltip: '메뉴 수정',
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.delete_outline, color: _restaurantName == '조이김밥' ? Colors.grey : Colors.red, size: 20),
                                                         onPressed: () {
                                                           if (_restaurantName == '조이김밥') {
                                                             showCustomDialog(
                                                               context: context,
                                                               title: '변경 불가',
                                                               content: '기본 설정 매장 [조이김밥]의 메뉴는 삭제할 수 없습니다.',
                                                             );
                                                             return;
                                                           }
                                                           _deleteMenuItem(_selectedCategory!, index);
                                                         },
                                                        tooltip: '메뉴 삭제',
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
