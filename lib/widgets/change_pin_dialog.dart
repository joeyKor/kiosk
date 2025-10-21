
import 'package:flutter/material.dart';

class ChangePinDialog extends StatefulWidget {
  const ChangePinDialog({super.key});

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String _enteredPin = '';
  bool _isConfirming = false;
  String _firstPin = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    setState(() {
      if (_enteredPin.length < 4) {
        _enteredPin += number;
        _pinController.text = '*' * _enteredPin.length;
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _pinController.text = '*' * _enteredPin.length;
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
    if (_enteredPin.length < 4) {
      // Not a valid PIN
      return;
    }
    if (!_isConfirming) {
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _pinController.clear();
        _isConfirming = true;
      });
    } else {
      if (_firstPin == _enteredPin) {
        Navigator.of(context).pop(_enteredPin);
      } else {
        Navigator.of(context).pop(null); // PINs do not match
      }
    }
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
      title: Text(_isConfirming ? '새 PIN 번호 확인' : '새 PIN 번호 입력'),
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
            Navigator.of(context).pop(); // User cancelled
          },
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _onConfirmPressed,
          child: Text(_isConfirming ? '확인' : '다음'),
        ),
      ],
    );
  }
}
