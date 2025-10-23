import 'dart:convert';
import 'dart:typed_data';

class MenuItem {
  String name;
  String? image; // This will now store the image URL from Firebase Storage
  int price;
  String category;

  MenuItem({
    required this.name,
    this.image,
    required this.price,
    required this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'],
      image: json['image'],
      price: json['price'],
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'price': price,
      'category': category,
    };
  }
}
