import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kiosk/pages/settings_page.dart';
import 'package:kiosk/models/menu_item.dart';

class OwnerModePage extends StatefulWidget {
  final String restaurantName;
  final List<String> categories;
  final Map<String, List<MenuItem>> menuItems;
  final String? imageFolderPath;
  final Function(List<String>, Map<String, List<MenuItem>>) onUpdate;

  const OwnerModePage({
    super.key,
    required this.restaurantName,
    required this.categories,
    required this.menuItems,
    required this.imageFolderPath,
    required this.onUpdate,
  });

  @override
  State<OwnerModePage> createState() => _OwnerModePageState();
}

class _OwnerModePageState extends State<OwnerModePage> {
  late AudioPlayer _audioPlayer;
  late FlutterTts _flutterTts;
  final Set<String> _announcedOrderIds = {};
  final Set<String> _announcedCallIds = {};
  bool _isFirstOrderLoad = true;
  bool _isFirstCallLoad = true;

  String _activeTab = 'order'; // 'order' (주문모드), 'completed' (완료내역), 'payment' (결제모드), 'payment_history' (결제내역)
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initTts();
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _playSound() async {
    if (!_soundEnabled) return;
    try {
      await _audioPlayer.play(AssetSource('audio/calls.mp3'));
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  void _announceTts(String text) {
    if (!_soundEnabled) return;
    _flutterTts.speak(text);
  }

  void _processNewOrders(List<QueryDocumentSnapshot> docs) {
    if (_isFirstOrderLoad) {
      for (final doc in docs) {
        _announcedOrderIds.add(doc.id);
      }
      _isFirstOrderLoad = false;
      return;
    }

    for (final doc in docs) {
      if (!_announcedOrderIds.contains(doc.id)) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final tableNumber = data['tableNumber'] as String?;
          if (tableNumber != null) {
            _playSound();
            _announceTts('$tableNumber번 테이블에 주문이 들어왔습니다.');
          }
        }
        _announcedOrderIds.add(doc.id);
      }
    }
  }

  void _processNewCalls(List<QueryDocumentSnapshot> docs) {
    if (_isFirstCallLoad) {
      for (final doc in docs) {
        _announcedCallIds.add(doc.id);
      }
      _isFirstCallLoad = false;
      return;
    }

    for (final doc in docs) {
      if (!_announcedCallIds.contains(doc.id)) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final tableNumber = data['tableNumber'] as String?;
          if (tableNumber != null) {
            _playSound();
            _announceTts('$tableNumber번 테이블에서 직원 호출이 들어왔습니다.');
          }
        }
        _announcedCallIds.add(doc.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day + 1));

    return Scaffold(
      backgroundColor: const Color(0xFF12131A), // Dark Background
      body: SafeArea(
        child: Column(
          children: [
            // Custom Dark Header Bar
            Container(
              color: const Color(0xFF000000),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Tab Buttons Group 1: 주문
                  _buildSegmentedGroup([
                    _buildSegmentedButton(
                      label: '주문모드',
                      isActive: _activeTab == 'order',
                      onTap: () => setState(() => _activeTab = 'order'),
                      activeColor: const Color(0xFF3B82F6),
                      isFirst: true,
                    ),
                    Container(width: 1, height: 24, color: const Color(0xFF2C2E3E)),
                    _buildSegmentedButton(
                      label: '완료내역',
                      isActive: _activeTab == 'completed',
                      onTap: () => setState(() => _activeTab = 'completed'),
                      activeColor: const Color(0xFF3B82F6),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(width: 12),
                  // Tab Buttons Group 2: 결제
                  _buildSegmentedGroup([
                    _buildSegmentedButton(
                      label: '결제모드',
                      isActive: _activeTab == 'payment',
                      onTap: () => setState(() => _activeTab = 'payment'),
                      activeColor: const Color(0xFF3B82F6),
                      isFirst: true,
                    ),
                    Container(width: 1, height: 24, color: const Color(0xFF2C2E3E)),
                    _buildSegmentedButton(
                      label: '결제내역',
                      isActive: _activeTab == 'payment_history',
                      onTap: () => setState(() => _activeTab = 'payment_history'),
                      activeColor: const Color(0xFF3B82F6),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(width: 16),
                  // Sound Toggle Button (Yellow/Gold)
                  GestureDetector(
                    onTap: () => setState(() => _soundEnabled = !_soundEnabled),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _soundEnabled ? const Color(0xFFECC94B) : const Color(0xFF2C2E3E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _soundEnabled ? '음향ON' : '음향OFF',
                        style: TextStyle(
                          color: _soundEnabled ? Colors.black : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Refresh Button
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => setState(() {}),
                  ),
                  const Spacer(),
                  // Shop Modify Button (가게 수정)
                  _buildHeaderButton(
                    label: '가게 수정',
                    isActive: false,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsPage(
                            categories: widget.categories,
                            menuItems: widget.menuItems,
                            onUpdate: widget.onUpdate,
                            imageFolderPath: widget.imageFolderPath,
                          ),
                        ),
                      );
                    },
                    color: const Color(0xFF2C2E3E),
                  ),
                  const SizedBox(width: 8),
                  // Exit Button (나가기)
                  _buildHeaderButton(
                    label: '나가기',
                    isActive: false,
                    onTap: () => Navigator.of(context).pop(),
                    color: const Color(0xFF2C2E3E),
                  ),
                ],
              ),
            ),
            // Dashboard Content Body
            Expanded(
              child: _buildBody(startOfToday, endOfToday),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E202C),
        border: Border.all(color: const Color(0xFF2C2E3E), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildSegmentedButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: isFirst ? const Radius.circular(4) : Radius.zero,
            bottomLeft: isFirst ? const Radius.circular(4) : Radius.zero,
            topRight: isLast ? const Radius.circular(4) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(4) : Radius.zero,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[400],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : const Color(0xFF2C2E3E),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[350],
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Timestamp startOfToday, Timestamp endOfToday) {
    if (_activeTab == 'order') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantName', isEqualTo: widget.restaurantName)
            .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
            .where('orderTime', isLessThan: endOfToday)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, orderSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('calls')
                .where('restaurantName', isEqualTo: widget.restaurantName)
                .where('time', isGreaterThanOrEqualTo: startOfToday)
                .where('time', isLessThan: endOfToday)
                .orderBy('time', descending: true)
                .snapshots(),
            builder: (context, callSnapshot) {
              final orders = orderSnapshot.data?.docs ?? [];
              final calls = callSnapshot.data?.docs ?? [];

              // Filter only active (non-completed) orders
              final activeOrders = orders.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return !(data['completed'] as bool? ?? false);
              }).toList();

              if (activeOrders.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _processNewOrders(activeOrders);
                });
              }

              if (calls.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _processNewCalls(calls);
                });
              }

              if (activeOrders.isEmpty && calls.isEmpty) {
                return const Center(
                  child: Text(
                    '진행 중인 주문이나 호출이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              return Row(
                children: [
                  // Active Orders Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            '진행 주문 내역',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: activeOrders.isEmpty
                              ? const Center(child: Text('진행 중인 주문이 없습니다.', style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: activeOrders.length,
                                  itemBuilder: (context, index) {
                                    final orderDoc = activeOrders[index];
                                    final orderData = orderDoc.data() as Map<String, dynamic>;
                                    final orderTime = (orderData['orderTime'] as Timestamp).toDate();
                                    final items = orderData['items'] as List<dynamic>;
                                    final totalPrice = orderData['totalPrice'] as int;
                                    final tableNumber = orderData['tableNumber'] as String;

                                    return Card(
                                      color: const Color(0xFF1E202C),
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '테이블: $tableNumber',
                                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  DateFormat('HH:mm').format(orderTime),
                                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            ...items.map((item) {
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                child: Text(
                                                  '• ${item['name']} x${item['quantity']}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                                ),
                                              );
                                            }).toList(),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${NumberFormat('#,##0', 'ko_KR').format(totalPrice)}원',
                                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    orderDoc.reference.update({'completed': true});
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF3B82F6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  ),
                                                  child: const Text('완료', style: TextStyle(color: Colors.white)),
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
                      ],
                    ),
                  ),
                  const VerticalDivider(color: Colors.grey, thickness: 0.5),
                  // Active Calls Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            '직원 호출 내역',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: calls.isEmpty
                              ? const Center(child: Text('호출 내역이 없습니다.', style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: calls.length,
                                  itemBuilder: (context, index) {
                                    final callDoc = calls[index];
                                    final callData = callDoc.data() as Map<String, dynamic>;
                                    final callTime = (callData['time'] as Timestamp).toDate();
                                    final tableNumber = callData['tableNumber'] as String;

                                    return Card(
                                      color: const Color(0xFF1E202C),
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      child: ListTile(
                                        title: Text(
                                          '테이블: $tableNumber',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        subtitle: Text(
                                          DateFormat('HH:mm:ss').format(callTime),
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            callDoc.reference.delete();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF007A87),
                                          ),
                                          child: const Text('확인', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } else if (_activeTab == 'completed') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantName', isEqualTo: widget.restaurantName)
            .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
            .where('orderTime', isLessThan: endOfToday)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final completedOrders = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['completed'] as bool? ?? false;
          }).toList();

          if (completedOrders.isEmpty) {
            return const Center(
              child: Text(
                '완료된 주문 내역이 없습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: completedOrders.length,
            itemBuilder: (context, index) {
              final orderDoc = completedOrders[index];
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final orderTime = (orderData['orderTime'] as Timestamp).toDate();
              final items = orderData['items'] as List<dynamic>;
              final totalPrice = orderData['totalPrice'] as int;
              final tableNumber = orderData['tableNumber'] as String;

              return Card(
                color: const Color(0xFF1E202C),
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: ListTile(
                  title: Text(
                    '테이블: $tableNumber (${DateFormat('HH:mm').format(orderTime)})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: items.map((item) {
                        return Text(
                          '${item['name']} x${item['quantity']}',
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        );
                      }).toList(),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${NumberFormat('#,##0', 'ko_KR').format(totalPrice)}원',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          orderDoc.reference.update({'completed': false});
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                        ),
                        child: const Text('되돌리기', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } else {
      // payment and payment_history placeholders
      return Center(
        child: Text(
          '${_activeTab == 'payment' ? '결제모드' : '결제내역'} 내역이 없습니다.',
          style: const TextStyle(color: Colors.grey, fontSize: 18),
        ),
      );
    }
  }
}
