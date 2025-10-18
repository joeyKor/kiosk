import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ImageDisplay extends StatelessWidget {
  final String? imagePath;
  final Uint8List? imageBytes;
  final bool isFile;

  const ImageDisplay({
    super.key,
    this.imagePath,
    this.imageBytes,
    required this.isFile,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBytes != null) {
      return Image.memory(imageBytes!, fit: BoxFit.cover);
    }
    if (isFile) {
      return Image.file(File(imagePath!), fit: BoxFit.cover);
    } else {
      return Image.network(imagePath!, fit: BoxFit.cover);
    }
  }
}
