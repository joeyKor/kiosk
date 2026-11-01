import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kiosk/widgets/image_display.dart';

void runAddToCartAnimation({
  required BuildContext context,
  required GlobalKey targetKey,
  required String itemName,
  String? imagePath,
  String? imageFolderPath,
  int quantity = 1,
}) {
  try {
    final OverlayState? overlayState = Overlay.of(context);
    if (overlayState == null) return;

    final RenderBox? startRenderBox = context.findRenderObject() as RenderBox?;
    if (startRenderBox == null || !startRenderBox.attached) return;
    final Offset startOffset = startRenderBox.localToGlobal(Offset.zero);
    final Size startSize = startRenderBox.size;

    final RenderBox? targetRenderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null || !targetRenderBox.attached) return;
    final Offset endOffset = targetRenderBox.localToGlobal(Offset.zero);
    final Size targetSize = targetRenderBox.size;

    // Center coordinates of start and target widgets
    final double startCenterX = startOffset.dx + startSize.width / 2;
    final double startCenterY = startOffset.dy + startSize.height / 2;

    final double endCenterX = endOffset.dx + targetSize.width / 2;
    final double endCenterY = endOffset.dy + targetSize.height / 2;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _FlyingCartItemEffect(
          startCenterX: startCenterX,
          startCenterY: startCenterY,
          endCenterX: endCenterX,
          endCenterY: endCenterY,
          targetSize: targetSize,
          itemName: itemName,
          imagePath: imagePath,
          imageFolderPath: imageFolderPath,
          quantity: quantity,
          onComplete: () {
            overlayEntry.remove();
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  } catch (e) {
    debugPrint("Add to cart animation error: $e");
  }
}

class _FlyingCartItemEffect extends StatefulWidget {
  final double startCenterX;
  final double startCenterY;
  final double endCenterX;
  final double endCenterY;
  final Size targetSize;
  final String itemName;
  final String? imagePath;
  final String? imageFolderPath;
  final int quantity;
  final VoidCallback onComplete;

  const _FlyingCartItemEffect({
    required this.startCenterX,
    required this.startCenterY,
    required this.endCenterX,
    required this.endCenterY,
    required this.targetSize,
    required this.itemName,
    this.imagePath,
    this.imageFolderPath,
    required this.quantity,
    required this.onComplete,
  });

  @override
  State<_FlyingCartItemEffect> createState() => _FlyingCartItemEffectState();
}

class _FlyingCartItemEffectState extends State<_FlyingCartItemEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flightProgress;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Flight starts slightly after initial pop-up (from 0.15 to 0.85)
    _flightProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.85, curve: Curves.easeInOutCubic),
    );

    // 3-Stage Scale: Pop-up big -> Stay large during flight -> Shrink into cart
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.45)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.45, end: 1.15)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 43,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 0.2)
            .chain(CurveTween(curve: Curves.easeInBack)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 15,
      ),
    ]).animate(_controller);

    // Opacity stays solid until absorbed into the cart button
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 12),
    ]).animate(_controller);

    // Slight dynamic tilt during parabolic flight
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -0.08), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -0.08, end: 0.12), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 0.12, end: 0.0), weight: 15),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double rawT = _controller.value;
          final double flightT = _flightProgress.value;

          // High parabolic arc (-170px peak)
          final double currentX = widget.startCenterX +
              (widget.endCenterX - widget.startCenterX) * flightT;
          final double arcHeight =
              -170.0 * (1.0 - (2.0 * flightT - 1.0) * (2.0 * flightT - 1.0));
          final double currentY = widget.startCenterY +
              (widget.endCenterY - widget.startCenterY) * flightT +
              arcHeight;

          // Start ripple progress (0.0 ~ 0.35)
          final double startRippleT = (rawT / 0.35).clamp(0.0, 1.0);

          // Target impact shockwave & badge bounce progress (0.75 ~ 1.0)
          final double impactT = ((rawT - 0.75) / 0.25).clamp(0.0, 1.0);

          return Stack(
            children: [
              // 1. Start Burst Ring Effect
              if (rawT < 0.35)
                Positioned(
                  left: widget.startCenterX - 60 * startRippleT,
                  top: widget.startCenterY - 60 * startRippleT,
                  child: Opacity(
                    opacity: (1.0 - startRippleT).clamp(0.0, 1.0),
                    child: Container(
                      width: 120 * startRippleT,
                      height: 120 * startRippleT,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE55A44),
                          width: 4 * (1.0 - startRippleT) + 1,
                        ),
                      ),
                    ),
                  ),
                ),

              // 2. Target Impact Shockwave & Pulse Overlay on Cart Button
              if (rawT >= 0.75) ...[
                // Expanding shockwave ring
                Positioned(
                  left: widget.endCenterX -
                      (widget.targetSize.width * (0.6 + 0.9 * impactT)) / 2,
                  top: widget.endCenterY -
                      (widget.targetSize.height * (0.6 + 1.3 * impactT)) / 2,
                  child: Opacity(
                    opacity: (1.0 - impactT).clamp(0.0, 1.0),
                    child: Container(
                      width: widget.targetSize.width * (0.6 + 0.9 * impactT),
                      height: widget.targetSize.height * (0.6 + 1.3 * impactT),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: const Color(0xFFE55A44),
                          width: 5 * (1.0 - impactT) + 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE55A44)
                                .withOpacity(0.4 * (1.0 - impactT)),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Floating "+N" pop badge above the cart button
                Positioned(
                  left: widget.endCenterX - 35,
                  top: widget.endCenterY -
                      widget.targetSize.height / 2 -
                      20 -
                      (35 * Curves.easeOut.transform(impactT)),
                  child: Opacity(
                    opacity: (1.0 - math.pow(impactT, 2)).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.8 + 0.5 * math.sin(impactT * math.pi),
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE55A44),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            '+${widget.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // 3. Main Flying Food Thumbnail Card + Badge
              if (rawT < 0.88)
                Positioned(
                  left: currentX - 85,
                  top: currentY - 65,
                  child: Opacity(
                    opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Material(
                          color: Colors.transparent,
                          child: SizedBox(
                            width: 170,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circular Food Thumbnail with glowing border & "+N" badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 92,
                                      height: 92,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: const Color(0xFFE55A44),
                                          width: 4,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE55A44)
                                                .withOpacity(0.45),
                                            blurRadius: 18,
                                            spreadRadius: 4,
                                          ),
                                          const BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 12,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: ImageDisplay(
                                          imagePath: widget.imagePath,
                                          imageFolderPath:
                                              widget.imageFolderPath,
                                          itemName: widget.itemName,
                                        ),
                                      ),
                                    ),
                                    // Quantity Badge on top-right of thumbnail
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE55A44),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '+${widget.quantity}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Item Name Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1D2026)
                                        .withOpacity(0.92),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.shopping_cart_checkout,
                                        color: Color(0xFFF3C63F),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          widget.itemName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
