
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kiosk/widgets/image_display.dart';

class LocalImageSelector extends StatefulWidget {
  final String? imageFolderPath;
  const LocalImageSelector({super.key, required this.imageFolderPath});

  @override
  State<LocalImageSelector> createState() => _LocalImageSelectorState();
}

class _LocalImageSelectorState extends State<LocalImageSelector> {
  late Future<List<File>> _imageFilesFuture;

  @override
  void initState() {
    super.initState();
    _imageFilesFuture = _loadImagesFromDirectory();
  }

  Future<List<File>> _loadImagesFromDirectory() async {
    if (widget.imageFolderPath == null) {
      return []; // Return empty list if no path is set
    }

    try {
      final kioskImagesDir = Directory(widget.imageFolderPath!);

      if (await kioskImagesDir.exists()) {
        final List<FileSystemEntity> entities = await kioskImagesDir.list().toList();
        return entities.whereType<File>().where((file) {
          final extension = file.path.split('.').last.toLowerCase();
          return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension);
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error loading images: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이미지 선택'),
      content: Container(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: widget.imageFolderPath == null
            ? const Center(
                child: Text(
                  '먼저 설정에서 이미지 폴더를 지정해주세요.',
                  textAlign: TextAlign.center,
                ),
              )
            : FutureBuilder<List<File>>(
                future: _imageFilesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        '선택한 폴더에 이미지가 없습니다.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final imageFiles = snapshot.data!;

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: imageFiles.length,
                    itemBuilder: (context, index) {
                      final file = imageFiles[index];
                      final filename = file.path.split(Platform.pathSeparator).last;

                      return GestureDetector(
                        onTap: () {
                          // Return the selected filename
                          Navigator.of(context).pop(filename);
                        },
                        child: GridTile(
                          footer: GridTileBar(
                            backgroundColor: Colors.black45,
                            title: Text(
                              filename,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          child: ImageDisplay(
                            imagePath: file.path,
                            isFile: true, // We pass the full path for preview
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
