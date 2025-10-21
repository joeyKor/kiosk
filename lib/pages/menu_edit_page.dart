import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart' as image_cropper;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/pages/web_crop_page.dart';
import 'package:kiosk/widgets/image_display.dart';

class MenuEditPage extends StatefulWidget {
  final String categoryName;
  final List<MenuItem> menuItems;
  final Function(List<MenuItem>) onUpdate;

  const MenuEditPage({
    super.key,
    required this.categoryName,
    required this.menuItems,
    required this.onUpdate,
  });

  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  late List<MenuItem> _menuItems;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _menuItems = widget.menuItems.map<MenuItem>((item) {
      return item;
      return MenuItem.fromJson(Map<String, dynamic>.from(item as Map));
    }).toList();
  }

  Future<void> _cropImageWeb(
    Uint8List bytes,
    Function(String?, bool, Uint8List?) setImage,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WebCropPage(
          imageBytes: bytes,
          onCropped: (croppedPath, isFile, bytes) {
            setImage(croppedPath, isFile, bytes);
          },
        ),
      ),
    );
  }

  Future<void> _pickImage(Function(String?, bool, Uint8List?) setImage) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        _cropImageWeb(bytes, setImage);
      } else {
        final image_cropper.CroppedFile? croppedFile =
            await image_cropper.ImageCropper().cropImage(
              sourcePath: image.path,
              aspectRatio: const image_cropper.CropAspectRatio(
                ratioX: 1,
                ratioY: 1,
              ),
              uiSettings: [
                image_cropper.AndroidUiSettings(
                  toolbarTitle: '이미지 자르기',
                  toolbarColor: Colors.blue,
                  toolbarWidgetColor: Colors.white,
                  initAspectRatio: image_cropper.CropAspectRatioPreset.square,
                  lockAspectRatio: true,
                ),
                image_cropper.IOSUiSettings(
                  title: '이미지 자르기',
                  doneButtonTitle: '완료',
                  cancelButtonTitle: '취소',
                  aspectRatioLockEnabled: true,
                ),
                image_cropper.WebUiSettings(context: context),
              ],
            );
        if (croppedFile != null) {
          setImage(croppedFile.path, true, null);
        }
      }
    }
  }

  void _showItemDialog({MenuItem? item, int? index}) {
    final isEditing = item != null;
    final nameController = TextEditingController(
      text: isEditing ? item.name : '',
    );
    final priceController = TextEditingController(
      text: isEditing ? item.price.toString() : '',
    );
    String? imagePath = isEditing ? item.image : null;
    Uint8List? imageBytes = isEditing ? item.imageBytes : null;
    bool isFile = isEditing ? item.isFile : false;

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
                    if (imagePath != null || imageBytes != null)
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: ImageDisplay(
                          imagePath: imagePath,
                          imageBytes: imageBytes,
                          isFile: isFile,
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.image),
                      label: const Text('이미지 선택'),
                      onPressed: () => _pickImage((path, file, bytes) {
                        setStateDialog(() {
                          imagePath = path;
                          isFile = file;
                          imageBytes = bytes;
                        });
                      }),
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
                    if (nameController.text.isNotEmpty &&
                        (imagePath != null || imageBytes != null) &&
                        priceController.text.isNotEmpty) {
                      final newItem = MenuItem(
                        name: nameController.text,
                        image: imagePath,
                        imageBytes: imageBytes,
                        isFile: isFile,
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
                    }
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
                imagePath: item.image,
                imageBytes: item.imageBytes,
                isFile: item.isFile,
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
