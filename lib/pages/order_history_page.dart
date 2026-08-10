import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/image_display.dart';

class OrderHistoryPage extends StatefulWidget {
  final String restaurantName;
  final String tableNumber;
  final Map<String, List<MenuItem>> menuItems;
  final String? imageFolderPath;

  const OrderHistoryPage({
    super.key,
    required this.restaurantName,
    required this.tableNumber,
    required this.menuItems,
    required this.imageFolderPath,
  });

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  String? _getItemImagePath(String name) {
    for (final categoryItems in widget.menuItems.values) {
      for (final item in categoryItems) {
        if (item.name == name) {
          return item.image;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Listener(
      onPointerDown: (_) => _startTimer(),
      onPointerMove: (_) => _startTimer(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: SafeArea(
          child: Column(
            children: [
              // Dark Header Bar
              Container(
                color: const Color(0xFF1E2026),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Table. ${widget.tableNumber.replaceAll(RegExp(r'[^0-9]'), '')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '주문 내역입니다.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              // Body Content
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('restaurantName', isEqualTo: widget.restaurantName)
                      .where('tableNumber', isEqualTo: widget.tableNumber)
                      .where('completed', isEqualTo: false)
                      .orderBy('orderTime', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF007A87)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          '진행 중인 주문 내역이 없습니다.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      );
                    }

                    // Aggregate items from all active orders
                    final List<Map<String, dynamic>> aggregatedItems = [];
                    for (final doc in snapshot.data!.docs) {
                      final orderData = doc.data() as Map<String, dynamic>;
                      final items = orderData['items'] as List<dynamic>;
                      for (final item in items) {
                        final name = item['name'] as String;
                        final quantity = (item['quantity'] as num).toInt();

                        final index = aggregatedItems.indexWhere((element) => element['name'] == name);
                        if (index != -1) {
                          aggregatedItems[index]['quantity'] += quantity;
                        } else {
                          aggregatedItems.add({
                            'name': name,
                            'quantity': quantity,
                          });
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Banner (Dark bar with 📢)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2E3E),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.campaign, color: Color(0xFFF3C63F), size: 24),
                                SizedBox(width: 12),
                                Text(
                                  '현재 주문 처리 및 조리 중인 내역입니다.',
                                  style: TextStyle(
                                    color: Color(0xFFF3C63F),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Ordered Items Grid / Cards Row
                          SizedBox(
                            height: 260,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: aggregatedItems.length,
                              itemBuilder: (context, index) {
                                final item = aggregatedItems[index];
                                final itemName = item['name'];
                                final quantity = item['quantity'];
                                final imagePath = _getItemImagePath(itemName);

                                return Container(
                                  width: 300,
                                  margin: const EdgeInsets.only(right: 16),
                                  child: Card(
                                    color: Colors.white,
                                    elevation: 1,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: ImageDisplay(
                                            imagePath: imagePath,
                                            imageFolderPath: widget.imageFolderPath,
                                            itemName: itemName,
                                          ),
                                        ),
                                        Container(
                                          height: 55,
                                          color: Colors.white,
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$itemName X $quantity',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
