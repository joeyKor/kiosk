import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/widgets/custom_dialog.dart';

class ShoppingCartPage extends StatefulWidget {
  final String restaurantName;
  final String tableNumber;

  const ShoppingCartPage({
    super.key,
    required this.restaurantName,
    required this.tableNumber,
  });

  @override
  State<ShoppingCartPage> createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  Future<void> _submitOrder() async {
    final cart = context.read<ShoppingCart>();
    if (cart.items.isEmpty) {
      return;
    }

    final orderData = {
      'orderTime': Timestamp.now(),
      'restaurantName': widget.restaurantName,
      'tableNumber': widget.tableNumber,
      'completed': false,
      'items': cart.items
          .map(
            (cartItem) => {
              'name': cartItem.item.name,
              'quantity': cartItem.quantity,
              'price': cartItem.item.price,
            },
          )
          .toList(),
      'totalPrice': cart.totalPrice,
    };

    try {
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      cart.clearCart();

      if (mounted) {
        showCustomDialog(
          context: context,
          title: '주문 완료',
          content: '주문이 성공적으로 완료되었습니다!',
        ).then((_) => Navigator.of(context).pop());
      }
    } catch (e) {
      if (mounted) {
        showCustomDialog(
          context: context,
          title: '오류',
          content: '주문 처리 중 오류가 발생했습니다: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: const Text('장바구니')),
      body: Consumer<ShoppingCart>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return const Center(child: Text('장바구니가 비어있습니다.'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: ImageDisplay(
                                imagePath: cartItem.item.image,
                                imageBytes: cartItem.item.imageBytes,
                                isFile: cartItem.item.isFile,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cartItem.item.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${currencyFormat.format(cartItem.item.price)}원',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    cart.decreaseQuantity(cartItem);
                                  },
                                ),
                                Text(
                                  '${cartItem.quantity}',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  onPressed: () {
                                    cart.increaseQuantity(cartItem);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    cart.removeItem(cartItem);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '총 주문 금액:',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(cart.totalPrice)}원',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '주문하기',
                          style: TextStyle(fontSize: 28, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: () {
                          cart.clearCart();
                          showCustomDialog(
                            context: context,
                            title: '알림',
                            content: '장바구니가 비워졌습니다.',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '장바구니 비우기',
                          style: TextStyle(fontSize: 28, color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
