import 'package:flutter/material.dart';

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
  final TextEditingController _pinController = TextEditingController();
  String _enteredPin = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_enteredPin.length < widget.correctPin.length) {
        _enteredPin += number;
        _pinController.text = '*' * _enteredPin.length; // Obscure text
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _pinController.text = '*' * _enteredPin.length; // Obscure text
      }
    });
  }

  void _onClearPressed() {
    setState(() {
      _enteredPin = '';
      _pinController.clear();
    });
  }

  void _onConfirmPressed() {
    Navigator.of(context).pop(_enteredPin == widget.correctPin);
  }

  Widget _buildNumberButton(String number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: () => _onNumberPressed(number),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(20),
            textStyle: const TextStyle(fontSize: 24),
          ),
          child: Text(number),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(20),
          ),
          child: Icon(icon),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN 번호 입력'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            readOnly: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, letterSpacing: 8),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintStyle: TextStyle(letterSpacing: 8),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                children: [
                  _buildNumberButton('1'),
                  _buildNumberButton('2'),
                  _buildNumberButton('3'),
                ],
              ),
              Row(
                children: [
                  _buildNumberButton('4'),
                  _buildNumberButton('5'),
                  _buildNumberButton('6'),
                ],
              ),
              Row(
                children: [
                  _buildNumberButton('7'),
                  _buildNumberButton('8'),
                  _buildNumberButton('9'),
                ],
              ),
              Row(
                children: [
                  _buildActionButton(Icons.backspace, _onBackspacePressed),
                  _buildNumberButton('0'),
                  _buildActionButton(Icons.clear, _onClearPressed),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false); // User cancelled
          },
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _onConfirmPressed,
          child: const Text('확인'),
        ),
      ],
    );
  }
}
