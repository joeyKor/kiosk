import 'dart:math';
import 'package:flutter/material.dart';

class RouletteWidget extends StatefulWidget {
  const RouletteWidget({super.key});

  @override
  State<RouletteWidget> createState() => _RouletteWidgetState();
}

class _RouletteWidgetState extends State<RouletteWidget> with SingleTickerProviderStateMixin {
  int _numParticipants = 3;
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _currentRotation = 0.0;
  bool _isSpinning = false;

  final List<Color> _colors = [
    const Color(0xFFE55A44), // Coral Red
    const Color(0xFFF3C63F), // Gold Yellow
    const Color(0xFF2CA05A), // Green
    const Color(0xFF3F7BF3), // Blue
    const Color(0xFF9C27B0), // Purple
    const Color(0xFFE91E63), // Pink
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFF9800), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );

    _animationController.addListener(() {
      setState(() {
        _currentRotation = _animation.value;
      });
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSpinComplete();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
    });

    final random = Random();
    // Choose a random number of full rotations plus a random offset
    final double targetRotation = _currentRotation + (5 + random.nextInt(5)) * 2 * pi + random.nextDouble() * 2 * pi;

    _animation = Tween<double>(
      begin: _currentRotation,
      end: targetRotation,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    ));

    _animationController.reset();
    _animationController.forward();
  }

  void _onSpinComplete() {
    setState(() {
      _isSpinning = false;
    });

    // Normalize final rotation to 0 - 2pi
    final double finalAngle = _currentRotation % (2 * pi);

    // The arrow is at the top (which is -pi/2 or 270 degrees relative to wheel's local space).
    // Rotation of wheel rotates segments clockwise.
    // So the segment at the top points to: angle = (3 * pi / 2 - finalAngle) % (2 * pi)
    double pointingAngle = (3 * pi / 2 - finalAngle) % (2 * pi);
    if (pointingAngle < 0) {
      pointingAngle += 2 * pi;
    }

    final double anglePerSegment = 2 * pi / _numParticipants;
    final int winnerIndex = (pointingAngle / anglePerSegment).floor() % _numParticipants;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E202C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            '🎯 오늘의 벌칙자!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _colors[winnerIndex],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${winnerIndex + 1}번',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '오늘 식사값은 ${winnerIndex + 1}번이 쏩니다! 🥳💸',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007A87),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF12131A), // Dark background for roulette
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Left: Roulette Wheel
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '내기 룰렛 돌리기 🎯',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '각자 번호를 하나씩 고른 후 SPIN을 눌러 당첨자를 뽑아보세요!',
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
                const SizedBox(height: 30),
                // Wheel Stack
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Rotating Custom Painted Wheel
                    Transform.rotate(
                      angle: _currentRotation,
                      child: CustomPaint(
                        size: const Size(400, 400),
                        painter: RoulettePainter(
                          numSegments: _numParticipants,
                          colors: _colors,
                        ),
                      ),
                    ),
                    // Center SPIN Button
                    GestureDetector(
                      onTap: _spinWheel,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'SPIN',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Arrow Pointer (At top)
                    Positioned(
                      top: -16,
                      child: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right: Settings Panel & Rules
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E202C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '내기 설정',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '참여 인원수 설정',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // Participant Count Incrementer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_numParticipants > 2) {
                            setState(() {
                              _numParticipants--;
                            });
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2C2E3E),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.remove, color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          '$_numParticipants명',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (_numParticipants < 8) {
                            setState(() {
                              _numParticipants++;
                            });
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF007A87),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.grey, thickness: 0.5),
                  const SizedBox(height: 16),
                  const Text(
                    '진행 규칙 💡',
                    style: TextStyle(color: Color(0xFFF3C63F), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildRuleText('1. 각자 순서대로 1번부터 번호를 하나씩 정합니다.'),
                  _buildRuleText('2. 번호 선정이 끝나면 룰렛을 돌립니다.'),
                  _buildRuleText('3. 화살표가 가리키는 당첨 번호에 배정된 사람이 패배자가 되어 오늘 쏘는 걸로 합니다!'),
                  const Spacer(),
                  // Legends
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12131A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: List.generate(_numParticipants, (index) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[index],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${index + 1}번',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.4),
      ),
    );
  }
}

// Custom Painter to draw the Roulette segments and names
class RoulettePainter extends CustomPainter {
  final int numSegments;
  final List<Color> colors;

  RoulettePainter({required this.numSegments, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final double sweepAngle = 2 * pi / numSegments;

    // Draw the segments
    for (int i = 0; i < numSegments; i++) {
      final double startAngle = i * sweepAngle;

      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Draw segment borders
      final borderPaint = Paint()
        ..color = const Color(0xFF12131A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      // Draw segment text (e.g. "1번")
      final double textAngle = startAngle + sweepAngle / 2;
      canvas.save();

      // Translate to center, rotate to segment angle, translate outwards
      canvas.translate(center.dx, center.dy);
      canvas.rotate(textAngle);

      final textSpan = TextSpan(
        text: '${i + 1}번',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout();

      // Position the text about 2/3 out of the radius, rotated so it reads outwards
      canvas.translate(radius * 0.6, 0);
      canvas.rotate(pi / 2); // Orient text nicely vertically along segment axis

      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      canvas.restore();
    }

    // Outer wheel border
    final outerPaint = Paint()
      ..color = const Color(0xFF1E202C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    canvas.drawCircle(center, radius, outerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
