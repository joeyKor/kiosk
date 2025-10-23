import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/menu_item_dialog.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';

class MenuGrid extends StatelessWidget {
  final List<MenuItem> items;
  final String? imageFolderPath;
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'ko_KR');

  MenuGrid({super.key, required this.items, required this.imageFolderPath});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('이 카테고리에 메뉴가 없습니다.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // Show 5 items per row to make them smaller
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 0.8, // Adjust aspect ratio
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final item = items[index];
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => MenuItemDialog(item: item, imageFolderPath: imageFolderPath),
            );
          },
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3, // Give more space to the image
                  child: ImageDisplay(
                    imagePath: item.image,
                    imageFolderPath: imageFolderPath,
                  ),
                ),
                Expanded( // Wrap the Padding in Expanded
                  flex: 2, // Give less space to the text
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20), // Increased font size
                        ),
                        Text('${currencyFormat.format(item.price)}원', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
