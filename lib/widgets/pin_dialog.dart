import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosk/widgets/custom_dialog.dart';

class PinDialog extends StatefulWidget {
  final String correctPin;

  const PinDialog({
    super.key,
    required this.correctPin,
  });

  @override
  State<PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<PinDialog> {
  String _enteredPin = '';

  void _onNumberPressed(String number) {
    if (_enteredPin.length < widget.correctPin.length) {
      setState(() {
        _enteredPin += number;
      });
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _enteredPin = '';
    });
  }

  void _onConfirmPressed() {
    Navigator.of(context).pop(_enteredPin == widget.correctPin);
  }

  Widget _buildKeyPadButton(String text, {IconData? icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2E3E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 22)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E202C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PIN 번호 확인',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.correctPin.length, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFF007A87) : Colors.grey[700],
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildKeyPadButton('1', onTap: () => _onNumberPressed('1')),
                _buildKeyPadButton('2', onTap: () => _onNumberPressed('2')),
                _buildKeyPadButton('3', onTap: () => _onNumberPressed('3')),
                _buildKeyPadButton('4', onTap: () => _onNumberPressed('4')),
                _buildKeyPadButton('5', onTap: () => _onNumberPressed('5')),
                _buildKeyPadButton('6', onTap: () => _onNumberPressed('6')),
                _buildKeyPadButton('7', onTap: () => _onNumberPressed('7')),
                _buildKeyPadButton('8', onTap: () => _onNumberPressed('8')),
                _buildKeyPadButton('9', onTap: () => _onNumberPressed('9')),
                _buildKeyPadButton('', icon: Icons.backspace_outlined, onTap: _onBackspacePressed),
                _buildKeyPadButton('0', onTap: () => _onNumberPressed('0')),
                _buildKeyPadButton('C', onTap: _onClearPressed),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('취소', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007A87),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StorePinDialog extends StatefulWidget {
  final String restaurantName;
  final String actionTitle;
  final String? storePassword;
  final String masterPin;

  const StorePinDialog({
    super.key,
    required this.restaurantName,
    required this.actionTitle,
    this.storePassword,
    required this.masterPin,
  });

  static Future<bool> show(
    BuildContext context, {
    required String restaurantName,
    required String actionTitle,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final masterPin = prefs.getString('adminPin') ?? '0000';

    final doc = await FirebaseFirestore.instance.collection('restaurants').doc(restaurantName).get();
    final data = doc.data();
    final storePassword = (data?['password'] as String?) ??
        (data?['pin'] as String?) ??
        (data?['pinNumber'] as String?) ??
        (data?['pinCode'] as String?);

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StorePinDialog(
        restaurantName: restaurantName,
        actionTitle: actionTitle,
        storePassword: storePassword,
        masterPin: masterPin,
      ),
    );

    if (result == false && context.mounted) {
      showCustomDialog(
        context: context,
        title: 'PIN 번호 오류',
        content: 'PIN 번호가 일치하지 않습니다.',
      );
    }

    return result == true;
  }

  @override
  State<StorePinDialog> createState() => _StorePinDialogState();
}

class _StorePinDialogState extends State<StorePinDialog> {
  String _enteredPin = '';

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
      });
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _enteredPin = '';
    });
  }

  void _onConfirmPressed() {
    if (_enteredPin.isEmpty) return;
    bool isCorrect = false;
    if (widget.storePassword != null && widget.storePassword!.isNotEmpty) {
      isCorrect = (_enteredPin == widget.storePassword || _enteredPin == widget.masterPin);
    } else {
      isCorrect = (_enteredPin == widget.masterPin);
    }
    Navigator.of(context).pop(isCorrect);
  }

  Widget _buildKeyPadButton(String text, {IconData? icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2E3E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon != null
              ? Icon(icon, color: Colors.white70, size: 22)
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E202C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '[${widget.restaurantName}] PIN 번호',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              '매장 ${widget.actionTitle}를 위해 PIN 번호 4자리를 입력하세요.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // 4-Dot Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFF007A87) : Colors.grey[700],
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // Keypad Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildKeyPadButton('1', onTap: () => _onNumberPressed('1')),
                _buildKeyPadButton('2', onTap: () => _onNumberPressed('2')),
                _buildKeyPadButton('3', onTap: () => _onNumberPressed('3')),
                _buildKeyPadButton('4', onTap: () => _onNumberPressed('4')),
                _buildKeyPadButton('5', onTap: () => _onNumberPressed('5')),
                _buildKeyPadButton('6', onTap: () => _onNumberPressed('6')),
                _buildKeyPadButton('7', onTap: () => _onNumberPressed('7')),
                _buildKeyPadButton('8', onTap: () => _onNumberPressed('8')),
                _buildKeyPadButton('9', onTap: () => _onNumberPressed('9')),
                _buildKeyPadButton('', icon: Icons.backspace_outlined, onTap: _onBackspacePressed),
                _buildKeyPadButton('0', onTap: () => _onNumberPressed('0')),
                _buildKeyPadButton('C', onTap: _onClearPressed),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('취소', style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007A87),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
