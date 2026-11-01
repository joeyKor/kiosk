import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiosk/widgets/custom_dialog.dart';

class ImageCropScreen extends StatefulWidget {
  final XFile file;

  const ImageCropScreen({super.key, required this.file});

  @override
  State<ImageCropScreen> createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  ui.Image? _uiImage;
  bool _isLoading = true;

  // InteractiveViewer TransformationController
  final TransformationController _transformationController = TransformationController();

  // Screen display dimensions for image
  double _displayW = 0;
  double _displayH = 0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _uiImage = frame.image;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading image for crop: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Target crop box dimensions matching MenuGrid's image area aspect ratio (0.85 / (6/9) = 1.275)
  static const double _targetBoxW = 360.0;
  static const double _targetBoxH = 282.0;

  Future<void> _cropAndSave() async {
    if (_uiImage == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF007A87)),
      ),
    );

    try {
      const double targetWidth = _targetBoxW;
      const double targetHeight = _targetBoxH;

      // Current transformation matrix
      final Matrix4 transform = _transformationController.value;
      final double s = transform.getMaxScaleOnAxis();
      final double tx = transform.storage[12];
      final double ty = transform.storage[13];

      // Top-left and bottom-right of the target box in child (displayed image) coordinates
      final double topLeftChildX = (0.0 - tx) / s;
      final double topLeftChildY = (0.0 - ty) / s;
      final double bottomRightChildX = (targetWidth - tx) / s;
      final double bottomRightChildY = (targetHeight - ty) / s;

      // Scale factors from child display size to native pixels
      final double scaleX = _uiImage!.width / _displayW;
      final double scaleY = _uiImage!.height / _displayH;

      final double cropX = topLeftChildX * scaleX;
      final double cropY = topLeftChildY * scaleY;
      final double cropW = (bottomRightChildX - topLeftChildX) * scaleX;
      final double cropH = (bottomRightChildY - topLeftChildY) * scaleY;

      // Output resolution strictly maintains the target aspect ratio (360:282)
      const double outW = 480.0;
      final double outH = (outW * targetHeight / targetWidth).roundToDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Fill background with white in case the user zoomed out beyond image bounds
      canvas.drawRect(
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..color = Colors.white,
      );

      // Map the exact crop rect (even if partially outside image bounds) onto the output canvas
      final Rect srcRect = Rect.fromLTWH(cropX, cropY, cropW, cropH);
      final Rect imgBounds = Rect.fromLTWH(0, 0, _uiImage!.width.toDouble(), _uiImage!.height.toDouble());
      final Rect validSrcRect = srcRect.intersect(imgBounds);

      if (!validSrcRect.isEmpty && validSrcRect.width > 0 && validSrcRect.height > 0) {
        final double dstLeft = ((validSrcRect.left - cropX) / cropW) * outW;
        final double dstTop = ((validSrcRect.top - cropY) / cropH) * outH;
        final double dstWidth = (validSrcRect.width / cropW) * outW;
        final double dstHeight = (validSrcRect.height / cropH) * outH;

        canvas.drawImageRect(
          _uiImage!,
          validSrcRect,
          Rect.fromLTWH(dstLeft, dstTop, dstWidth, dstHeight),
          Paint()..filterQuality = ui.FilterQuality.high,
        );
      }

      final croppedUiImage = await recorder.endRecording().toImage(outW.round(), outH.round());
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Failed to convert image to byte data.');
      }
      
      final croppedBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.pop(context); // Pop progress dialog
        Navigator.pop(context, croppedBytes); // Return cropped bytes
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop progress dialog
        showCustomDialog(
          context: context,
          title: '오류',
          content: '이미지를 자르는데 실패했습니다: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double targetBoxW = _targetBoxW;
    const double targetBoxH = _targetBoxH;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('이미지 편집', style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('자르기 완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: _isLoading ? null : _cropAndSave,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF007A87)))
          : LayoutBuilder(
              builder: (context, constraints) {
                final double screenW = constraints.maxWidth;
                final double screenH = constraints.maxHeight;

                if (_displayW == 0 && _displayH == 0) {
                  // Fit image so it covers the target crop box (cover fit)
                  final double imgAspect = _uiImage!.width / _uiImage!.height;
                  final double targetAspect = targetBoxW / targetBoxH;

                  if (imgAspect > targetAspect) {
                    _displayH = targetBoxH;
                    _displayW = targetBoxH * imgAspect;
                  } else {
                    _displayW = targetBoxW;
                    _displayH = targetBoxW / imgAspect;
                  }

                  final double initialTx = (targetBoxW - _displayW) / 2;
                  final double initialTy = (targetBoxH - _displayH) / 2;
                  _transformationController.value = Matrix4.identity()..translate(initialTx, initialTy);
                }

                // Center crop overlay
                final double overlayLeft = (screenW - targetBoxW) / 2;
                final double overlayTop = (screenH - targetBoxH) / 2;

                return Stack(
                  children: [
                    // Interactive image layer
                    Center(
                      child: SizedBox(
                        width: targetBoxW,
                        height: targetBoxH,
                        child: ClipRect(
                          clipBehavior: Clip.none,
                          child: InteractiveViewer(
                            constrained: false,
                            transformationController: _transformationController,
                            boundaryMargin: const EdgeInsets.all(double.infinity),
                            minScale: 0.2,
                            maxScale: 5.0,
                            child: SizedBox(
                              width: _displayW,
                              height: _displayH,
                              child: RawImage(
                                image: _uiImage,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Mask Layer with cutout rectangle
                    IgnorePointer(
                      child: Stack(
                        children: [
                          // Top dark area
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: overlayTop,
                            child: Container(color: Colors.black.withOpacity(0.6)),
                          ),
                          // Bottom dark area
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: screenH - overlayTop - targetBoxH,
                            child: Container(color: Colors.black.withOpacity(0.6)),
                          ),
                          // Left dark area
                          Positioned(
                            top: overlayTop,
                            left: 0,
                            width: overlayLeft,
                            height: targetBoxH,
                            child: Container(color: Colors.black.withOpacity(0.6)),
                          ),
                          // Right dark area
                          Positioned(
                            top: overlayTop,
                            right: 0,
                            width: screenW - overlayLeft - targetBoxW,
                            height: targetBoxH,
                            child: Container(color: Colors.black.withOpacity(0.6)),
                          ),
                          // Clear cutout rectangle border
                          Positioned(
                            left: overlayLeft,
                            top: overlayTop,
                            width: targetBoxW,
                            height: targetBoxH,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFF007A87), width: 2),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.crop,
                                  color: Colors.white.withOpacity(0.3),
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hint Text
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '손가락으로 이미지를 확대/축소 및 이동하여 원하는 사각형 박스에 맞추세요.',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
