
import 'package:flutter/material.dart';
import 'package:kiosk/models/menu_item.dart';
import 'main.dart'; // Assuming MenuItem is in main.dart

class CartItem {
  final MenuItem item;
  int quantity;

  CartItem({required this.item, this.quantity = 1});

  Map<String, dynamic> toJson() {
    return {
      'item': item.toJson(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      item: MenuItem.fromJson(json['item']),
      quantity: json['quantity'],
    );
  }
}

class ShoppingCart extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get totalPrice {
    return _items.fold(0, (sum, current) => sum + current.item.price * current.quantity);
  }

  int get itemCount {
    return _items.fold(0, (sum, current) => sum + current.quantity);
  }

  void addItem(MenuItem item, int quantity) {
    for (var cartItem in _items) {
      if (cartItem.item.name == item.name) {
        cartItem.quantity += quantity;
        notifyListeners();
        return;
      }
    }
    _items.add(CartItem(item: item, quantity: quantity));
    notifyListeners();
  }

  void removeItem(CartItem cartItem) {
    _items.remove(cartItem);
    notifyListeners();
  }

  void increaseQuantity(CartItem cartItem) {
    cartItem.quantity++;
    notifyListeners();
  }

  void decreaseQuantity(CartItem cartItem) {
    if (cartItem.quantity > 1) {
      cartItem.quantity--;
      notifyListeners();
    } else {
      removeItem(cartItem);
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}
