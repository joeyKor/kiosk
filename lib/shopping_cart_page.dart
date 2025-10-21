import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:kiosk/shopping_cart.dart';
import 'package:kiosk/widgets/image_display.dart';
import 'package:kiosk/widgets/custom_dialog.dart';
import 'package:kiosk/util/decrypt.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingCartPage extends StatefulWidget {
  final String restaurantName;
  final String tableNumber;

  const ShoppingCartPage({
    super.key,
    required this.restaurantName,
    required this.tableNumber,
  });

  @override
  State<ShoppingCartPage> createState() => _ShoppingCartPageState();
}

class _ShoppingCartPageState extends State<ShoppingCartPage> {
  Future<void> _submitOrder() async {
    final cart = context.read<ShoppingCart>();
    if (cart.items.isEmpty) {
      return;
    }

    final orderData = {
      'orderTime': Timestamp.now(),
      'restaurantName': widget.restaurantName,
      'tableNumber': widget.tableNumber,
      'completed': false,
      'items': cart.items
          .map(
            (cartItem) => {
              'name': cartItem.item.name,
              'quantity': cartItem.quantity,
              'price': cartItem.item.price,
            },
          )
          .toList(),
      'totalPrice': cart.totalPrice,
    };

    try {
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      cart.clearCart();

      if (mounted) {
        showCustomDialog(
          context: context,
          title: '주문 완료',
          content: '주문이 성공적으로 완료되었습니다!',
        ).then(
          (_) => Navigator.of(context).popUntil((route) => route.isFirst),
        ); // Navigate to main screen
      }
    } catch (e) {
      if (mounted) {
        showCustomDialog(
          context: context,
          title: '오류',
          content: '주문 처리 중 오류가 발생했습니다: $e',
        );
      }
    }
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.5,
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.money, size: 48),
                    label: const Text('현금결제', style: TextStyle(fontSize: 24)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _submitOrder();
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 48),
                    label: const Text('페이결제', style: TextStyle(fontSize: 24)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showPayPaymentDialog();
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPayPaymentDialog() {
    final cart = context.read<ShoppingCart>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _PayPaymentDialog(
          totalPrice: cart.totalPrice,
          onSubmit: _submitOrder,
          restaurantName: widget.restaurantName,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: const Text('장바구니')),
      body: Consumer<ShoppingCart>(
        builder: (context, cart, child) {
          if (cart.items.isEmpty) {
            return const Center(child: Text('장바구니가 비어있습니다.'));
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = cart.items[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              height: 60,
                              child: ImageDisplay(
                                imagePath: cartItem.item.image,
                                imageBytes: cartItem.item.imageBytes,
                                isFile: cartItem.item.isFile,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cartItem.item.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${currencyFormat.format(cartItem.item.price)}원',
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle),
                                  onPressed: () {
                                    cart.decreaseQuantity(cartItem);
                                  },
                                ),
                                Text(
                                  '${cartItem.quantity}',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle),
                                  onPressed: () {
                                    cart.increaseQuantity(cartItem);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    cart.removeItem(cartItem);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '총 주문 금액:',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${currencyFormat.format(cart.totalPrice)}원',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _showPaymentDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '주문하기',
                          style: TextStyle(fontSize: 28, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton(
                        onPressed: () {
                          cart.clearCart();
                          showCustomDialog(
                            context: context,
                            title: '알림',
                            content: '장바구니가 비워졌습니다.',
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '장바구니 비우기',
                          style: TextStyle(fontSize: 28, color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PayPaymentDialog extends StatefulWidget {
  final int totalPrice;
  final Future<void> Function() onSubmit;
  final String restaurantName;

  const _PayPaymentDialog({
    required this.totalPrice,
    required this.onSubmit,
    required this.restaurantName,
  });

  @override
  _PayPaymentDialogState createState() => _PayPaymentDialogState();
}

class _PayPaymentDialogState extends State<_PayPaymentDialog> {
  final _accountController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _accountController.addListener(() {
      if (!_isLoading && _accountController.text.length == 16) {
        _processPayment();
      }
    });
  }

  Future<void> _processPayment() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("결제중..."),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    try {
      final decryptedAccountId = simpleDecrypt(_accountController.text);
      final amountToWithdraw = widget.totalPrice;

      final accountsRef = FirebaseFirestore.instance
          .collectionGroup('accounts')
          .where('accountNumber', isEqualTo: decryptedAccountId);
      final accountDocs = await accountsRef.get();
      final targetAccountRef = accountDocs.docs.first.reference;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(targetAccountRef);
        if (!snapshot.exists) {
          throw Exception("계좌를 찾을 수 없습니다.");
        }

        final currentBalance = snapshot.get("balance");
        if (currentBalance < amountToWithdraw) {
          throw Exception("잔액이 부족합니다.");
        }

        final newBalance = currentBalance - amountToWithdraw;
        transaction.update(targetAccountRef, {"balance": newBalance});

        final userDocRef = targetAccountRef.parent.parent;
        if (userDocRef == null) {
          throw Exception("Could not find user document.");
        }
        final newTransactionRef = userDocRef.collection('transactions').doc();

        final transactionData = {
          'amount': amountToWithdraw,
          'balance_after': newBalance,
          'description': widget.restaurantName,
          'is_deposit': false,
          'memo_to_me': '',
          'memo_to_recipient': '',
          'recipientName': widget.restaurantName,
          'senderName': snapshot.data()?['accountHolderName'] ?? '고객',
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'PAYMENT',
        };
        transaction.set(newTransactionRef, transactionData);
      });

      Navigator.of(context).pop(); // Close processing dialog
      setState(() {
        _isLoading = false;
      });

      await showCustomDialog(
        context: context,
        title: '결제 완료',
        content: '${widget.totalPrice}원 결제가 완료되었습니다.',
      );

      await widget.onSubmit();
      Navigator.of(context).pop(); // Close payment dialog
    } catch (e) {
      Navigator.of(context).pop(); // Close processing dialog
      setState(() {
        _isLoading = false;
      });
      showCustomDialog(context: context, title: '결제 오류', content: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: AlertDialog(
        title: const Text('페이결제'),
        content: SizedBox(
          width: 300, // Adjust as needed
          height: 200, // Adjust as needed
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                '결제처: ${widget.restaurantName}\n결제금액: ${widget.totalPrice}원',
                textAlign: TextAlign
                    .center, // Added for better formatting with two lines
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ), // Increased font size
              ),
              const SizedBox(height: 20),
                          TextField(
                            controller: _accountController,
                            autofocus: true,
                            enabled: !_isLoading, // Disable TextField when loading
                            obscureText: true, // Hide the input text
                            style: TextStyle(color: Theme.of(context).canvasColor),
                            decoration: const InputDecoration(
                              border: InputBorder.none, // Made the border invisible
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: null, // Removed the character counter
                          ),            ],
          ),
        ),
        actions: [], // Removed the cancel button
      ),
    );
  }
}
