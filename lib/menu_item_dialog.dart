import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:provider/provider.dart';

class MenuItemDialog extends StatefulWidget {
  final MenuItem item;

  const MenuItemDialog({super.key, required this.item});

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
    final cart = Provider.of<ShoppingCart>(context, listen: false);

    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Expanded(child: SizedBox(height: 20)),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: ImageDisplay(
                  imagePath: widget.item.image,
                  imageBytes: widget.item.imageBytes,
                  isFile: widget.item.isFile,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${currencyFormat.format(widget.item.price)}원',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.grey,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle, size: 36),
                            onPressed: () => _updateQuantity(-1),
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, size: 36),
                            onPressed: () => _updateQuantity(1),
                          ),
                        ],
                      ),
                      Text(
                        '총 금액: ${currencyFormat.format(_totalPrice)}원',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: () {
                            cart.addItem(widget.item, _quantity);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '담기',
                            style: TextStyle(fontSize: 28, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
