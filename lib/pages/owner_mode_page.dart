import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerModePage extends StatelessWidget {
  final String restaurantName;

  const OwnerModePage({super.key, required this.restaurantName});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1));

    return Scaffold(
      appBar: AppBar(
        title: Text('가게 모드 - $restaurantName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantName', isEqualTo: restaurantName)
            .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
            .where('orderTime', isLessThan: endOfToday)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다. Firestore 색인을 확인해주세요.\n${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('오늘의 주문 내역이 없습니다.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final orderDoc = snapshot.data!.docs[index];
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final orderTime = (orderData['orderTime'] as Timestamp).toDate();
              final items = orderData['items'] as List<dynamic>;
              final totalPrice = orderData['totalPrice'] as int;
              final tableNumber = orderData['tableNumber'] as String;
              final isCompleted = orderData['completed'] as bool;

              return Card(
                color: isCompleted ? Colors.grey[300] : Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(
                    '테이블: $tableNumber - ${DateFormat('HH:mm').format(orderTime)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) => Text('${item['name']} x${item['quantity']}')).toList(),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${NumberFormat('#,##0', 'ko_KR').format(totalPrice)}원',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: isCompleted,
                          onChanged: (value) {
                            orderDoc.reference.update({'completed': value});
                          },
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
