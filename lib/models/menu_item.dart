import 'dart:convert';
import 'dart:typed_data';

class MenuItem {
  String name;
  String? image; // This will now store the image URL from Firebase Storage
  int price;
  String category;
  String? description;
  bool isBest;
  bool isNew;
  int order;
  bool isSoldOut;

  MenuItem({
    required this.name,
    this.image,
    required this.price,
    required this.category,
    this.description = '',
    this.isBest = false,
    this.isNew = false,
    this.order = 0,
    this.isSoldOut = false,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'],
      image: json['image'],
      price: json['price'],
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      isBest: json['isBest'] ?? false,
      isNew: json['isNew'] ?? false,
      order: json['order'] ?? 0,
      isSoldOut: json['isSoldOut'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'price': price,
      'category': category,
      'description': description,
      'isBest': isBest,
      'isNew': isNew,
      'order': order,
      'isSoldOut': isSoldOut,
    };
  }
}
