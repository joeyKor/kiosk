import 'dart:io';

import 'package:flutter/material.dart';

class ImageDisplay extends StatelessWidget {
  final String? imagePath; // Can be a filename or a full path for previews
  final String? imageFolderPath; // The base path to the user-selected image folder
  final bool isFile; // True if imagePath is a full path to a local file (for previews)

  const ImageDisplay({
    super.key,
    this.imagePath,
    this.imageFolderPath,
    this.isFile = false,
  });

  @override
  Widget build(BuildContext context) {
    // Case 1: Previewing a newly selected image from the LocalImageSelector.
    // Here, imagePath is a full, absolute path.
    if (imagePath != null && isFile) {
      final previewFile = File(imagePath!);
      if (previewFile.existsSync()) {
        return Image.file(previewFile, fit: BoxFit.cover);
      }
    }

    // Case 2: Displaying a persisted image from the configured folder.
    // Here, imagePath is just the filename.
    if (imageFolderPath != null && imagePath != null) {
      final imageFile = File('$imageFolderPath/$imagePath');
      if (imageFile.existsSync()) {
        return Image.file(imageFile, fit: BoxFit.cover);
      }
    }

    // Case 3: No image available or file not found, show a placeholder.
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }
}
