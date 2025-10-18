import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class WebCropPage extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(String?, bool, Uint8List?) onCropped;

  const WebCropPage({
    super.key,
    required this.imageBytes,
    required this.onCropped,
  });

  @override
  State<WebCropPage> createState() => _WebCropPageState();
}

class _WebCropPageState extends State<WebCropPage> {
  final _controller = CropController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Image'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              _controller.crop();
            },
          ),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        onCropped: (image) {
          widget.onCropped(null, false, image);
          Navigator.pop(context);
        },
      ),
    );
  }
}
