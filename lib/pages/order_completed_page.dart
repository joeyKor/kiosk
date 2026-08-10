import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/widgets/image_display.dart';

class OrderCompletedPage extends StatefulWidget {
  final String tableNumber;
  final List<CartItem> orderedItems;
  final String? imageFolderPath;

  const OrderCompletedPage({
    super.key,
    required this.tableNumber,
    required this.orderedItems,
    required this.imageFolderPath,
  });

  @override
  State<OrderCompletedPage> createState() => _OrderCompletedPageState();
}

class _OrderCompletedPageState extends State<OrderCompletedPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Auto-close after 7 seconds
    _timer = Timer(const Duration(seconds: 7), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            // Dark Header Bar
            Container(
              color: const Color(0xFF1E2026),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Table. ${widget.tableNumber.replaceAll(RegExp(r'[^0-9]'), '')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '주문 완료 되었습니다.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            // Body Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Banner (Dark bar with 📢)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2E3E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.campaign, color: Color(0xFFF3C63F), size: 24),
                          SizedBox(width: 12),
                          Text(
                            '주문이 완료되었습니다.',
                            style: TextStyle(
                              color: Color(0xFFF3C63F),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Ordered Items Grid / Cards Row
                    SizedBox(
                      height: 260,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.orderedItems.length,
                        itemBuilder: (context, index) {
                          final cartItem = widget.orderedItems[index];
                          return Container(
                            width: 300,
                            margin: const EdgeInsets.only(right: 16),
                            child: Card(
                              color: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ImageDisplay(
                                      imagePath: cartItem.item.image,
                                      imageFolderPath: widget.imageFolderPath,
                                    ),
                                  ),
                                  Container(
                                    height: 55,
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${cartItem.item.name} X ${cartItem.quantity}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
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
    );
  }
}
