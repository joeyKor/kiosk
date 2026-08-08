import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:provider/provider.dart';
import 'package:kiosk/main.dart';
import 'package:kiosk/util/add_to_cart_animation.dart';

class MenuItemDialog extends StatefulWidget {
  final MenuItem item;
  final String? imageFolderPath;

  const MenuItemDialog({super.key, required this.item, required this.imageFolderPath});

  @override
  State<MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<MenuItemDialog> {
  int _quantity = 1;
  late int _totalPrice;
  final currencyFormat = NumberFormat('#,##0', 'ko_KR');

  @override
  void initState() {
    super.initState();
    _totalPrice = widget.item.price;
  }

  void _updateQuantity(int change) {
    setState(() {
      _quantity = (_quantity + change).clamp(1, 99);
      _totalPrice = widget.item.price * _quantity;
    });
  }



  @override
  Widget build(BuildContext context) {
    final bool isBest = widget.item.isBest;
    final bool isNew = widget.item.isNew;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.65,
        color: Colors.white,
        child: Stack(
          children: [
            Column(
              children: [
                // Upper body containing two columns
                Expanded(
                  child: Row(
                    children: [
                      // Left Section: Image and Name/Price
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image with optional BEST/NEW badges
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ImageDisplay(
                                          imagePath: widget.item.image,
                                          imageFolderPath: widget.imageFolderPath,
                                          itemName: widget.item.name,
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
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.item.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${currencyFormat.format(widget.item.price)}원',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Vertical Divider
                      VerticalDivider(color: Colors.grey[200], width: 1, thickness: 1),
                      
                      // Right Section: Description
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item.description ?? '',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Horizontal Divider
                Divider(color: Colors.grey[200], height: 1, thickness: 1),
                
                // Bottom control row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity controls
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 28, color: Colors.grey),
                            onPressed: () => _updateQuantity(-1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 28, color: Colors.grey),
                            onPressed: () => _updateQuantity(1),
                          ),
                        ],
                      ),
                      
                      // Total price & 담기 Button
                      Row(
                        children: [
                          Text(
                            '${currencyFormat.format(_totalPrice)}원',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            height: 50,
                            width: 140,
                            child: Builder(
                              builder: (btnContext) {
                                return ElevatedButton(
                                  onPressed: () {
                                    context.read<ShoppingCart>().addItem(
                                      widget.item,
                                      _quantity,
                                    );
                                    runAddToCartAnimation(
                                      context: btnContext,
                                      targetKey: KioskHomePage.cartTargetKey,
                                      itemName: widget.item.name,
                                    );
                                    Navigator.pop(context);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007A87),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const Text(
                                    '담기',
                                    style: TextStyle(
                                      fontSize: 20,
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
              ],
            ),
            
            // Close (X) button at top-right
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
