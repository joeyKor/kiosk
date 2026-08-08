import 'package:flutter/material.dart';

void runAddToCartAnimation({
  required BuildContext context,
  required GlobalKey targetKey,
  required String itemName,
}) {
  try {
    final OverlayState? overlayState = Overlay.of(context);
    if (overlayState == null) return;

    final RenderBox? startRenderBox = context.findRenderObject() as RenderBox?;
    if (startRenderBox == null || !startRenderBox.attached) return;
    final Offset startOffset = startRenderBox.localToGlobal(Offset.zero);
    final Size startSize = startRenderBox.size;

    final RenderBox? targetRenderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null || !targetRenderBox.attached) return;
    final Offset endOffset = targetRenderBox.localToGlobal(Offset.zero);

    // Center of start widget
    final double startX = startOffset.dx + startSize.width / 2 - 20;
    final double startY = startOffset.dy + startSize.height / 2 - 20;

    // Center of target widget
    final double endX = endOffset.dx + targetRenderBox.size.width / 2 - 15;
    final double endY = endOffset.dy + targetRenderBox.size.height / 2 - 15;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _FlyingCartIcon(
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          itemName: itemName,
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

class _FlyingCartIcon extends StatefulWidget {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final String itemName;
  final VoidCallback onComplete;

  const _FlyingCartIcon({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.itemName,
    required this.onComplete,
  });

  @override
  State<_FlyingCartIcon> createState() => _FlyingCartIconState();
}

class _FlyingCartIconState extends State<_FlyingCartIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 1.2, end: 0.3).animate(_animation);
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_animation);

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _animation.value;
        // Parabolic arc path calculation
        final currentX = widget.startX + (widget.endX - widget.startX) * t;
        final arcHeight = -60 * (1 - (2 * t - 1) * (2 * t - 1));
        final currentY = widget.startY + (widget.endY - widget.startY) * t + arcHeight;

        return Positioned(
          left: currentX,
          top: currentY,
          child: Opacity(
            opacity: _opacityAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE55A44),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE55A44).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
