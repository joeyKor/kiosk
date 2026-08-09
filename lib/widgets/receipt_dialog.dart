import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceiptDialog extends StatelessWidget {
  final String restaurantName;
  final String tableNumber;
  final int totalPrice;
  final int balanceAfter;
  final List<Map<String, dynamic>> items; // [{'name': ..., 'quantity': ..., 'price': ...}]
  final String paymentMethod;
  final DateTime dateTime;

  final int? receivedAmount;
  final int? changeAmount;

  const ReceiptDialog({
    super.key,
    required this.restaurantName,
    required this.tableNumber,
    required this.totalPrice,
    required this.balanceAfter,
    required this.items,
    this.paymentMethod = '조이페이',
    required this.dateTime,
    this.receivedAmount,
    this.changeAmount,
  });

  static Future<void> show({
    required BuildContext context,
    required String restaurantName,
    required String tableNumber,
    required int totalPrice,
    required int balanceAfter,
    required List<Map<String, dynamic>> items,
    String paymentMethod = '조이페이',
    int? receivedAmount,
    int? changeAmount,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ReceiptDialog(
          restaurantName: restaurantName,
          tableNumber: tableNumber,
          totalPrice: totalPrice,
          balanceAfter: balanceAfter,
          items: items,
          paymentMethod: paymentMethod,
          dateTime: DateTime.now(),
          receivedAmount: receivedAmount,
          changeAmount: changeAmount,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 380,
          margin: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFD), // Off-white receipt paper color
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Zigzag line decorator
              Container(
                height: 6,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ZigzagPainter(),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Text(
                      restaurantName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '[ 신 용 영 수 증 ]',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info Rows
                    _buildInfoRow('일  시', dateFormat.format(dateTime)),
                    _buildInfoRow('테이블', '$tableNumber번 테이블'),
                    _buildInfoRow('결제구분', paymentMethod),
                    const SizedBox(height: 10),
                    
                    // Dashed Divider
                    _buildDashedLine(),
                    const SizedBox(height: 10),

                    // Item Header
                    Row(
                      children: const [
                        Expanded(
                          flex: 5,
                          child: Text(
                            '상품명',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '수량',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            '금액',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildDashedLine(),
                    const SizedBox(height: 8),

                    // Items List (Limited height scrollable or simple column if small)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Column(
                          children: items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${item['quantity']}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '${currencyFormat.format(item['price'] * item['quantity'])}원',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDashedLine(),
                    const SizedBox(height: 10),

                    // Total & Balance
                    _buildTotalRow('합계 금액', '${currencyFormat.format(totalPrice)}원', isBold: true),
                    const SizedBox(height: 6),
                    _buildTotalRow('받은 금액 ($paymentMethod)', '${currencyFormat.format(receivedAmount ?? totalPrice)}원'),
                    if (changeAmount != null && changeAmount! > 0) ...[
                      const SizedBox(height: 6),
                      _buildTotalRow('거스름돈', '${currencyFormat.format(changeAmount)}원', isHighlight: true),
                    ],
                    
                    const SizedBox(height: 16),
                    _buildDashedLine(),
                    const SizedBox(height: 16),
                    
                    const Text(
                      '이용해 주셔서 감사합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              
              // Bottom Button Area
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 44,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF1E202C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFFD32F2F) : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black38),
              ),
            );
          }),
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
        );
      },
    );
  }
}

class _ZigzagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFDFDFD)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    
    double x = 0;
    double y = size.height;
    const double step = 8;
    bool up = true;

    while (x < size.width) {
      x += step;
      y = up ? 0 : size.height;
      path.lineTo(x, y);
      up = !up;
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
