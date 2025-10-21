import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kiosk/widgets/custom_dialog.dart';

class OwnerModePage extends StatefulWidget {
  final String restaurantName;

  const OwnerModePage({super.key, required this.restaurantName});

  @override
  State<OwnerModePage> createState() => _OwnerModePageState();
}

class _OwnerModePageState extends State<OwnerModePage> {
  late AudioPlayer _audioPlayer;
  int _previousOrderCount = 0;
  int _previousCallCount = 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSound() async {
    await _audioPlayer.play(AssetSource('audio/calls.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1));

    return Scaffold(
      appBar: AppBar(
        title: Text('가게 모드 - ${widget.restaurantName}'),
      ),
      body: Row(
        children: [
          // Left side: Order List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('restaurantName', isEqualTo: widget.restaurantName)
                  .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
                  .where('orderTime', isLessThan: endOfToday)
                  .orderBy('orderTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('주문 내역 오류: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentOrderCount = snapshot.data!.docs.length;
                if (_previousOrderCount != 0 && currentOrderCount > _previousOrderCount) {
                  _playSound();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showCustomDialog(
                      context: context,
                      title: '새로운 주문',
                      content: '새로운 주문이 도착했습니다!',
                    );
                  });
                }
                _previousOrderCount = currentOrderCount;

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
                    final paymentMethod = orderData['paymentMethod'] as String? ?? 'N/A';

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: isCompleted ? Colors.grey[300] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: ListTile(
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '테이블: $tableNumber',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              ...items.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                                  child: Text(
                                    '${item['name']} x${item['quantity']}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '주문 시간: ${DateFormat('HH:mm').format(orderTime)} ($paymentMethod)',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${NumberFormat('#,##0', 'ko_KR').format(totalPrice)}원',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: isCompleted,
                                onChanged: (value) {
                                  orderDoc.reference.update({'completed': value});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Right side: Staff Call List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '직원 호출 내역',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('calls')
                          .where('restaurantName', isEqualTo: widget.restaurantName)
                          .where('time', isGreaterThanOrEqualTo: startOfToday)
                          .where('time', isLessThan: endOfToday)
                          .orderBy('time', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('호출 내역 오류: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final currentCallCount = snapshot.data!.docs.length;
                        if (_previousCallCount != 0 && currentCallCount > _previousCallCount) {
                          _playSound();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            showCustomDialog(
                              context: context,
                              title: '직원 호출',
                              content: '새로운 직원 호출이 들어왔습니다!',
                            );
                          });
                        }
                        _previousCallCount = currentCallCount;

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('오늘의 직원 호출 내역이 없습니다.'));
                        }

                        return ListView.builder(
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final callDoc = snapshot.data!.docs[index];
                            final callData = callDoc.data() as Map<String, dynamic>;
                            final callTime = (callData['time'] as Timestamp).toDate();
                            final tableNumber = callData['tableNumber'] as String;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              child: ListTile(
                                title: Text('테이블: $tableNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(DateFormat('HH:mm:ss').format(callTime)),
                                trailing: ElevatedButton(
                                  onPressed: () {
                                    callDoc.reference.delete();
                                  },
                                  child: const Text('확인'),
                                ),
                              ),
                            );
                          },
                        );
                      },
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
}
