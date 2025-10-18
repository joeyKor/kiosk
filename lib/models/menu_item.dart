import 'dart:convert';
import 'dart:typed_data';

class MenuItem {
  String name;
  String? image;
  Uint8List? imageBytes;
  bool isFile;
  int price;
  String category;

  MenuItem({
    required this.name,
    this.image,
    this.imageBytes,
    this.isFile = false,
    required this.price,
    required this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      name: json['name'],
      image: json['image'],
      imageBytes: json['imageBytes'] != null
          ? base64Decode(json['imageBytes'])
          : null,
      isFile: json['isFile'],
      price: json['price'],
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'imageBytes': imageBytes != null ? base64Encode(imageBytes!) : null,
      'isFile': isFile,
      'price': price,
      'category': category,
    };
  }
}
