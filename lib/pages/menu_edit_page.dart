import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/widgets/local_image_selector.dart';
import 'package:path/path.dart' as p;

class MenuEditPage extends StatefulWidget {
  final String categoryName;
  final List<MenuItem> menuItems;
  final Function(List<MenuItem>) onUpdate;
  final String? imageFolderPath;

  const MenuEditPage({
    super.key,
    required this.categoryName,
    required this.menuItems,
    required this.onUpdate,
    required this.imageFolderPath,
  });

  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  late List<MenuItem> _menuItems;

  @override
  void initState() {
    super.initState();
    _menuItems = widget.menuItems.map((item) => MenuItem.fromJson(item.toJson())).toList();
  }

  void _showItemDialog({MenuItem? item, int? index}) {
    final isEditing = item != null;
    final nameController = TextEditingController(
      text: isEditing ? item.name : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? item.price.toString() : '',
    );
    
    // This now holds the FILENAME of the image, e.g., 'americano.jpg'
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
                        imagePath: imageFilename, // Pass the filename to the display widget
                        imageFolderPath: widget.imageFolderPath,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('이미지 선택'),
                      onPressed: () async {
                        final String? selectedFilename = await showDialog<String>(
                          context: context,
                          builder: (_) => LocalImageSelector(imageFolderPath: widget.imageFolderPath),
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
                      image: imageFilename, // Save the selected filename
                      price: int.tryParse(priceController.text) ?? 0,
                      category: widget.categoryName,
                    );
                    
                    setState(() {
                      if (isEditing) {
                        _menuItems[index!] = newItem;
                      } else {
                        _menuItems.add(newItem);
                      }
                    });

                    widget.onUpdate(_menuItems);
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

  void _deleteMenuItem(int index) {
    setState(() {
      _menuItems.removeAt(index);
    });
    widget.onUpdate(_menuItems);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.categoryName} 메뉴 수정')),
      body: ListView.builder(
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return ListTile(
            leading: SizedBox(
              width: 50,
              height: 50,
              child: ImageDisplay(
                imagePath: item.image, // This is now a filename
                imageFolderPath: widget.imageFolderPath,
              ),
            ),
            title: Text(item.name),
            subtitle: Text('${currencyFormat.format(item.price)}원'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showItemDialog(item: item, index: index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteMenuItem(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        label: const Text('메뉴 추가', style: TextStyle(fontSize: 18, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.red,
      ),
    );
  }
}
