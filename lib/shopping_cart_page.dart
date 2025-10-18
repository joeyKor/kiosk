import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/order.dart';

import 'package:provider/provider.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShoppingCartPage extends StatefulWidget {
  const ShoppingCartPage({super.key});

  @override
  State<ShoppingCartPage> createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  Future<void> _saveOrder(List<CartItem> items, int totalPrice) async {
    final prefs = await SharedPreferences.getInstance();
    final String? ordersString = prefs.getString('orders');
    List<Order> orders = [];
    if (ordersString != null) {
      final List<dynamic> decodedList = jsonDecode(ordersString);
      orders = decodedList.map((item) => Order.fromJson(item)).toList();
    }
    orders.add(Order(items: items, totalPrice: totalPrice, date: DateTime.now()));
    final String encodedList =
        jsonEncode(orders.map((order) => order.toJson()).toList());
    await prefs.setString('orders', encodedList);
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
                        onPressed: () {
                          if (cart.items.isNotEmpty) {
                            _saveOrder(cart.items, cart.totalPrice);
                            cart.clearCart();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('주문이 완료되었습니다!')),
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '주문하기',
                          style: TextStyle(
                              fontSize: 28, color: Colors.white),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('장바구니가 비워졌습니다.')),
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
