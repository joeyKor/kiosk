import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/menu_item_dialog.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/main.dart';
import 'package:kiosk/util/add_to_cart_animation.dart';

import 'package:kiosk/services/localization_service.dart';

class MenuGrid extends StatelessWidget {
  final List<MenuItem> items;
  final String? imageFolderPath;
  final String langCode;
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'ko_KR');

  MenuGrid({
    super.key,
    required this.items,
    required this.imageFolderPath,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          langCode == 'ko' ? '이 카테고리에 메뉴가 없습니다.' : 'No items in this category.',
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // Show 3 items per row to match reference image
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        childAspectRatio: 0.85, // Proper layout ratio for landscape
      ),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final item = items[index];
        final bool isBest = item.isBest;
        final bool isNew = item.isNew;
        
        final translatedName = LocalizationService.instance.translateMenuItemName(item.name, langCode);
        final translatedDesc = LocalizationService.instance.translateMenuItemDescription(item.description ?? '', item.name, langCode);

        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => MenuItemDialog(item: item, imageFolderPath: imageFolderPath),
            );
          },
          child: Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Section with optional BEST/NEW badges
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ImageDisplay(
                          imagePath: item.image,
                          imageFolderPath: imageFolderPath,
                          itemName: item.name,
                        ),
                      ),
                      if (isBest)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3C63F),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'BEST',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      if (isNew)
                        Positioned(
                          top: 10,
                          left: isBest ? 65 : 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Details Section
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          translatedName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Text(
                            translatedDesc,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${currencyFormat.format(item.price)}원',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(
                              height: 36,
                              child: Builder(
                                builder: (btnContext) {
                                  return ElevatedButton(
                                    onPressed: () {
                                      context.read<ShoppingCart>().addItem(item, 1);
                                      runAddToCartAnimation(
                                        context: btnContext,
                                        targetKey: KioskHomePage.cartTargetKey,
                                        itemName: item.name,
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1D2026),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    child: Text(
                                      langCode == 'ko' ? '담기' : 'Add',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                              ),
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
        );
      },
    );
  }
}
