import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageDisplay extends StatelessWidget {
  final String? imagePath; // Can be a filename or a full path for previews
  final String? imageFolderPath; // The base path to the user-selected image folder
  final bool isFile; // True if imagePath is a full path to a local file (for previews)
  final String? itemName; // Optional menu item name to match bundled assets

  const ImageDisplay({
    super.key,
    this.imagePath,
    this.imageFolderPath,
    this.isFile = false,
    this.itemName,
  });

  static String? getAssetForName(String? name) {
    if (name == null) return null;
    if (name.contains('조이김밥')) return 'assets/images/joy_gimbap.png';
    if (name.contains('참치김밥')) return 'assets/images/tuna_gimbap.png';
    if (name.contains('치즈김밥')) return 'assets/images/cheese_gimbap.png';
    if (name.contains('김치김밥')) return 'assets/images/kimchi_gimbap.png';
    if (name.contains('돈가스') || name.contains('돈까스')) return 'assets/images/tonkatsu_gimbap.png';
    if (name.contains('스팸김밥')) return 'assets/images/spam_gimbap.png';
    if (name.contains('떡볶이')) return 'assets/images/tteokbokki.png';
    if (name.contains('모듬튀김') || name.contains('튀김')) return 'assets/images/fried_platter.png';
    if (name.contains('순대')) return 'assets/images/soondae.png';
    if (name.contains('콜라')) return 'assets/images/cola.png';
    if (name.contains('사이다')) return 'assets/images/cider.png';
    if (name.contains('쿨피스')) return 'assets/images/coolpis.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have an explicit asset or a name match
    final matchedAsset = getAssetForName(itemName);
    final effectiveImagePath = imagePath ?? matchedAsset;

    // Case 0: Displaying a local asset image bundled in the app (e.g. starts with 'images/' or 'assets/')
    if (effectiveImagePath != null &&
        (effectiveImagePath.startsWith('images/') || effectiveImagePath.startsWith('assets/'))) {
      final assetPath = effectiveImagePath.startsWith('assets/') ? effectiveImagePath : 'assets/$effectiveImagePath';
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }

    // Case 0.5: Displaying a network image from a URL or relative web asset
    if (imagePath != null &&
        (imagePath!.startsWith('http://') ||
            imagePath!.startsWith('https://') ||
            imagePath!.startsWith('blob:') ||
            kIsWeb)) {
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          if (matchedAsset != null) {
            return Image.asset(matchedAsset, fit: BoxFit.cover);
          }
          return _buildPlaceholder();
        },
      );
    }

    // Case 1: Previewing a newly selected image from the LocalImageSelector.
    if (!kIsWeb && imagePath != null && isFile) {
      final previewFile = File(imagePath!);
      if (previewFile.existsSync()) {
        return Image.file(previewFile, fit: BoxFit.cover);
      }
    }

    // Case 2: Displaying a persisted image from the configured folder.
    if (!kIsWeb && imageFolderPath != null && imagePath != null) {
      final imageFile = File('$imageFolderPath/$imagePath');
      if (imageFile.existsSync()) {
        return Image.file(imageFile, fit: BoxFit.cover);
      }
    }

    // Fallback case: Matched asset by menu name if available
    if (matchedAsset != null) {
      return Image.asset(matchedAsset, fit: BoxFit.cover);
    }

    // Case 3: No image available or file not found, show a placeholder.
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
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
