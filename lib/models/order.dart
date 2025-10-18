import 'package:kiosk/shopping_cart.dart';

class Order {
  final List<CartItem> items;
  final int totalPrice;
  final DateTime date;

  Order({required this.items, required this.totalPrice, required this.date});

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => item.toJson()).toList(),
      'totalPrice': totalPrice,
      'date': date.toIso8601String(),
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      items: (json['items'] as List).map((item) => CartItem.fromJson(item)).toList(),
      totalPrice: json['totalPrice'],
      date: DateTime.parse(json['date']),
    );
  }
}
