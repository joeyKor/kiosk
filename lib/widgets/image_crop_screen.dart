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
      // 4:3 Crop box target dimensions (center of screen)
      const double targetWidth = 360.0;
      const double targetHeight = 270.0;

      // Current transformation matrix
      final Matrix4 transform = _transformationController.value;
      final double s = transform.getMaxScaleOnAxis();
      final double tx = transform.storage[12];
      final double ty = transform.storage[13];

      // Top-left of the target box in child (displayed image) coordinates
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

      // Clamp crop rectangle inside original image dimensions
      final int finalX = cropX.clamp(0.0, _uiImage!.width.toDouble()).round();
      final int finalY = cropY.clamp(0.0, _uiImage!.height.toDouble()).round();
      final int finalW = cropW.clamp(1.0, (_uiImage!.width - finalX).toDouble()).round();
      final int finalH = cropH.clamp(1.0, (_uiImage!.height - finalY).toDouble()).round();

      // Resize cropped image to optimal menu resolution (max 400x300 px)
      // to keep Base64 payload small (~50KB) and strictly respect Firestore's 1MB document size limit.
      const double maxDim = 400.0;
      double outW = finalW.toDouble();
      double outH = finalH.toDouble();
      if (outW > maxDim || outH > maxDim) {
        if (outW >= outH) {
          outH = (outH * maxDim) / outW;
          outW = maxDim;
        } else {
          outW = (outW * maxDim) / outH;
          outH = maxDim;
        }
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.drawImageRect(
        _uiImage!,
        Rect.fromLTWH(finalX.toDouble(), finalY.toDouble(), finalW.toDouble(), finalH.toDouble()),
        Rect.fromLTWH(0, 0, outW, outH),
        Paint()..filterQuality = ui.FilterQuality.high,
      );

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
    const double targetBoxW = 360.0;
    const double targetBoxH = 270.0;

    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2229),
        title: const Text('이미지 편집 (4:3 비율)', style: TextStyle(color: Colors.white, fontSize: 18)),
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
                          child: InteractiveViewer(
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
