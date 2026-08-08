import 'dart:async';
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

class _OwnerModePageState extends State<OwnerModePage>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late FlutterTts _flutterTts;
  final Set<String> _announcedOrderIds = {};
  final Set<String> _announcedCallIds = {};
  bool _isFirstOrderLoad = true;
  bool _isFirstCallLoad = true;

  String _activeTab = 'order'; // 'order' (주문모드), 'completed' (완료내역), 'payment' (결제모드), 'payment_history' (결제내역)
  bool _soundEnabled = true;

  late AnimationController _flashController;
  late Animation<Color?> _borderColorAnimation;
  bool _isFlashing = false;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initTts();

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _borderColorAnimation = ColorTween(
      begin: Colors.red,
      end: Colors.white,
    ).animate(_flashController);
  }

  void _startFlashingBorder() {
    _flashTimer?.cancel();
    setState(() {
      _isFlashing = true;
    });
    _flashController.repeat(reverse: true);

    _flashTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _flashController.stop();
        _flashController.reset();
        setState(() {
          _isFlashing = false;
        });
      }
    });
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('ko-KR');
    await _flutterTts.setSpeechRate(0.5);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _flashController.dispose();
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
          _startFlashingBorder();
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
          _startFlashingBorder();
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

    return AnimatedBuilder(
      animation: _borderColorAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            border: _isFlashing
                ? Border.all(
                    color: _borderColorAnimation.value ?? Colors.red,
                    width: 6.0,
                  )
                : null,
          ),
          child: child,
        );
      },
      child: Scaffold(
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

              final List<_OwnerCardData> combinedCards = [];

              for (final doc in activeOrders) {
                final data = doc.data() as Map<String, dynamic>;
                final time = (data['orderTime'] as Timestamp).toDate();
                final rawTable = data['tableNumber'] as String? ?? '';
                final tableNum = rawTable.replaceAll(RegExp(r'[^0-9]'), '');

                combinedCards.add(_OwnerCardData(
                  id: doc.id,
                  isCall: false,
                  tableNumber: tableNum.isEmpty ? rawTable : tableNum,
                  time: time,
                  items: data['items'] as List<dynamic>?,
                  reference: doc.reference,
                ));
              }

              for (final doc in calls) {
                final data = doc.data() as Map<String, dynamic>;
                final time = (data['time'] as Timestamp).toDate();
                final rawTable = data['tableNumber'] as String? ?? '';
                final tableNum = rawTable.replaceAll(RegExp(r'[^0-9]'), '');

                combinedCards.add(_OwnerCardData(
                  id: doc.id,
                  isCall: true,
                  tableNumber: tableNum.isEmpty ? rawTable : tableNum,
                  time: time,
                  reference: doc.reference,
                ));
              }

              combinedCards.sort((a, b) => a.time.compareTo(b.time));

              if (combinedCards.isEmpty) {
                return const Center(
                  child: Text(
                    '진행 중인 주문이나 호출이 없습니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.25,
                  ),
                  itemCount: combinedCards.length,
                  itemBuilder: (context, index) {
                    final card = combinedCards[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E202C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row: Table Number Box, Time, [호출] badge, OK button
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  card.tableNumber,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('HH:mm').format(card.time),
                                style: const TextStyle(
                                  color: Color(0xFFEC407A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (card.isCall) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE55A44),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    '[호출]',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  if (card.isCall) {
                                    card.reference.delete();
                                  } else {
                                    card.reference.update({'completed': true});
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF007A87),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Content: Order Items list OR Call Icon & Text
                          Expanded(
                            child: card.isCall
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.notifications_active,
                                          color: Color(0xFFE55A44),
                                          size: 44,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          '직원 호출',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: card.items?.length ?? 0,
                                    itemBuilder: (context, itemIdx) {
                                      final item = card.items![itemIdx];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text(
                                          '${item['name']} x ${item['quantity']}',
                                          style: const TextStyle(
                                            color: Color(0xFFF3C63F),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
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

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.25,
              ),
              itemCount: completedOrders.length,
              itemBuilder: (context, index) {
                final orderDoc = completedOrders[index];
                final orderData = orderDoc.data() as Map<String, dynamic>;
                final orderTime = (orderData['orderTime'] as Timestamp).toDate();
                final items = orderData['items'] as List<dynamic>? ?? [];
                final rawTable = orderData['tableNumber'] as String? ?? '';
                final tableNum = rawTable.replaceAll(RegExp(r'[^0-9]'), '');
                final displayTable = tableNum.isEmpty ? rawTable : tableNum;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E202C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Table Box, Time, 복구 Button
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              displayTable,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(orderTime),
                            style: const TextStyle(
                              color: Color(0xFFEC407A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              orderDoc.reference.update({'completed': false});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE55A44),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '복구',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Content: Items List
                      Expanded(
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, itemIdx) {
                            final item = items[itemIdx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                '${item['name']} x ${item['quantity']}',
                                style: const TextStyle(
                                  color: Color(0xFFF3C63F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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

class _OwnerCardData {
  final String id;
  final bool isCall;
  final String tableNumber;
  final DateTime time;
  final List<dynamic>? items;
  final DocumentReference reference;

  _OwnerCardData({
    required this.id,
    required this.isCall,
    required this.tableNumber,
    required this.time,
    this.items,
    required this.reference,
  });
}
