import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:provider/provider.dart';

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
      _quantity = (_quantity + change).clamp(
        1,
        99,
      ); // Quantity between 1 and 99
      _totalPrice = widget.item.price * _quantity;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Row(
              children: [
                Expanded(flex: 1, child: SizedBox(width: 10)),
                // Left side: Image
                Expanded(
                  flex: 10,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      bottomLeft: Radius.circular(20.0),
                    ),
                    child: ImageDisplay(
                      imagePath: widget.item.image,
                      imageFolderPath: widget.imageFolderPath,
                    ),
                  ),
                ),
                Expanded(flex: 1, child: SizedBox(width: 10)),
                // Right side: Details
                Expanded(
                  flex: 15,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${currencyFormat.format(widget.item.price)}원',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 40,
                                color: Colors.black54,
                              ),
                              onPressed: () => _updateQuantity(-1),
                            ),
                            const SizedBox(width: 20),
                            Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 40,
                                color: Colors.black54,
                              ),
                              onPressed: () => _updateQuantity(1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '총 금액',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              '${currencyFormat.format(_totalPrice)}원',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.read<ShoppingCart>().addItem(
                                widget.item,
                                _quantity,
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white,
                            ),
                            label: const Text(
                              '장바구니에 담기',
                              style: TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                              ),
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
          // Close Button
          Positioned(
            top: -10,
            right: -10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.close, color: Colors.black54, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
