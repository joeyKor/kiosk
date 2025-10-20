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

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '주문 시간: ${DateFormat('yyyy-MM-dd HH:mm').format(orderTime)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      ...items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item['name']} x${item['quantity']}', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        );
                      }).toList(),
                      const Divider(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '총 금액: ${currencyFormat.format(totalPrice)}원',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
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
