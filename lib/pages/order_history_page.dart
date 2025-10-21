import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OrderHistoryPage extends StatelessWidget {
  final String restaurantName;
  final String tableNumber;

  const OrderHistoryPage({
    super.key,
    required this.restaurantName,
    required this.tableNumber,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,##0', 'ko_KR');

    return Scaffold(
      appBar: AppBar(
        title: Text('테이블 $tableNumber 주문 내역'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantName', isEqualTo: restaurantName)
            .where('tableNumber', isEqualTo: tableNumber)
            .where('completed', isEqualTo: false)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('진행중인 주문 내역이 없습니다.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final orderDoc = snapshot.data!.docs[index];
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final orderTime = (orderData['orderTime'] as Timestamp).toDate();
              final items = orderData['items'] as List<dynamic>;
              final totalPrice = orderData['totalPrice'] as int;
              final paymentMethod = orderData['paymentMethod'] as String? ?? 'N/A';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5.0),
                          child: Text(
                            '${item['name']} x${item['quantity']}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                          ),
                        );
                      }).toList(),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '주문 시간: ${DateFormat('HH:mm').format(orderTime)} ($paymentMethod)',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                    trailing: Text(
                      '${currencyFormat.format(totalPrice)}원',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
