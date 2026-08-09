import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kiosk/pages/settings_page.dart';
import 'package:kiosk/pages/program_settings_page.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/widgets/custom_dialog.dart';
import 'package:kiosk/widgets/pin_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String _restaurantNameState = '';
  String? _imageFolderPathState;

  @override
  void initState() {
    super.initState();
    _restaurantNameState = widget.restaurantName;
    _imageFolderPathState = widget.imageFolderPath;
    _loadSettings();
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _restaurantNameState = prefs.getString('restaurantName') ?? widget.restaurantName;
        _imageFolderPathState = prefs.getString('imageFolderPath') ?? widget.imageFolderPath;
      });
    }
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
                        final authenticated = await StorePinDialog.show(
                          context,
                          restaurantName: _restaurantNameState,
                          actionTitle: '가게 수정',
                        );
                        if (authenticated) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingsPage(
                                categories: widget.categories,
                                menuItems: widget.menuItems,
                                onUpdate: widget.onUpdate,
                                imageFolderPath: _imageFolderPathState,
                              ),
                            ),
                          );
                          await _loadSettings();
                        }
                      },
                      color: const Color(0xFF2C2E3E),
                    ),
                    const SizedBox(width: 8),
                    // Program Settings Button (프로그램 설정 변경)
                    _buildHeaderButton(
                      label: '프로그램 설정 변경',
                      isActive: false,
                      onTap: () async {
                        final authenticated = await StorePinDialog.show(
                          context,
                          restaurantName: _restaurantNameState,
                          actionTitle: '프로그램 설정 변경',
                        );
                        if (authenticated) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProgramSettingsPage(),
                            ),
                          );
                          await _loadSettings();
                        }
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
            .where('restaurantName', isEqualTo: _restaurantNameState)
            .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
            .where('orderTime', isLessThan: endOfToday)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, orderSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('calls')
                .where('restaurantName', isEqualTo: _restaurantNameState)
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
            .where('restaurantName', isEqualTo: _restaurantNameState)
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
            final isCompleted = data['completed'] as bool? ?? false;
            final isPaid = data['paid'] as bool? ?? false;
            return isCompleted && !isPaid;
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
    } else if (_activeTab == 'payment') {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantName', isEqualTo: _restaurantNameState)
            .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
            .where('orderTime', isLessThan: endOfToday)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final Map<String, _TablePaymentSummary> tableSummaries = {};

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final isPaid = data['paid'] as bool? ?? false;
            if (isPaid) continue; // Skip already paid orders

            final rawTable = data['tableNumber'] as String? ?? '0';
            final tableNum = rawTable.replaceAll(RegExp(r'[^0-9]'), '');
            final displayTable = tableNum.isEmpty ? rawTable : tableNum;

            final summary = tableSummaries.putIfAbsent(
              displayTable,
              () => _TablePaymentSummary(displayTable),
            );
            summary.orderReferences.add(doc.reference);

            final itemList = data['items'] as List<dynamic>? ?? [];
            for (final item in itemList) {
              final name = item['name'] as String? ?? '';
              final qty = item['quantity'] as int? ?? 1;
              final unitPrice = item['price'] as int? ?? 0;

              if (summary.items.containsKey(name)) {
                summary.items[name]!.quantity += qty;
              } else {
                summary.items[name] = _AggregatedItem(
                  name: name,
                  quantity: qty,
                  unitPrice: unitPrice,
                );
              }
              summary.totalAmount += (unitPrice * qty);
            }
          }

          final summariesList = tableSummaries.values.toList();

          if (summariesList.isEmpty) {
            return const Center(
              child: Text(
                '결제 대기 중인 테이블이 없습니다.',
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
                childAspectRatio: 0.88,
              ),
              itemCount: summariesList.length,
              itemBuilder: (context, index) {
                final summary = summariesList[index];
                final aggregatedItems = summary.items.values.toList();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E202C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Table Box & 결제하기 Button
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
                              summary.tableNumber,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _showTablePaymentDialog(context, summary);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2E3E),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey[700]!, width: 1),
                              ),
                              child: const Text(
                                '결제하기',
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
                      // Content: Aggregated Item List with prices
                      Expanded(
                        child: ListView.builder(
                          itemCount: aggregatedItems.length,
                          itemBuilder: (context, itemIdx) {
                            final item = aggregatedItems[itemIdx];
                            final lineTotal = item.unitPrice * item.quantity;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.name} x ${item.quantity}',
                                    style: const TextStyle(
                                      color: Color(0xFFF3C63F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${NumberFormat('#,##0', 'ko_KR').format(lineTotal)}원',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(color: Color(0xFF2C2E3E), height: 20),
                      // Bottom Footer: 총 금액
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '총 금액',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${NumberFormat('#,##0', 'ko_KR').format(summary.totalAmount)}원',
                            style: const TextStyle(
                              color: Color(0xFFF3C63F),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
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
      // payment_history tab
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('restaurantName', isEqualTo: _restaurantNameState)
            .where('orderTime', isGreaterThanOrEqualTo: startOfToday)
            .where('orderTime', isLessThan: endOfToday)
            .orderBy('orderTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final Map<String, _PaidTransactionSummary> transactionSummaries = {};

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final isPaid = data['paid'] as bool? ?? false;
            if (!isPaid) continue; // Only process paid orders in payment_history!
            final rawTable = data['tableNumber'] as String? ?? '0';
            final tableNum = rawTable.replaceAll(RegExp(r'[^0-9]'), '');
            final displayTable = tableNum.isEmpty ? rawTable : tableNum;

            final paymentId = data['paymentId'] as String? ?? doc.id;
            final paidTime = data['paidTime'] != null
                ? (data['paidTime'] as Timestamp).toDate()
                : (data['orderTime'] as Timestamp).toDate();

            final summary = transactionSummaries.putIfAbsent(
              paymentId,
              () => _PaidTransactionSummary(
                paymentId: paymentId,
                tableNumber: displayTable,
                paidTime: paidTime,
              ),
            );
            summary.orderReferences.add(doc.reference);

            final itemList = data['items'] as List<dynamic>? ?? [];
            for (final item in itemList) {
              final name = item['name'] as String? ?? '';
              final qty = item['quantity'] as int? ?? 1;
              final unitPrice = item['price'] as int? ?? 0;

              if (summary.items.containsKey(name)) {
                summary.items[name]!.quantity += qty;
              } else {
                summary.items[name] = _AggregatedItem(
                  name: name,
                  quantity: qty,
                  unitPrice: unitPrice,
                );
              }
              summary.totalAmount += (unitPrice * qty);
            }
          }

          final transactionsList = transactionSummaries.values.toList();
          transactionsList.sort((a, b) => b.paidTime.compareTo(a.paidTime));

          if (transactionsList.isEmpty) {
            return const Center(
              child: Text(
                '결제 완료된 내역이 없습니다.',
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
                childAspectRatio: 0.88,
              ),
              itemCount: transactionsList.length,
              itemBuilder: (context, index) {
                final summary = transactionsList[index];
                final aggregatedItems = summary.items.values.toList();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E202C),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Table Box, Paid Time, 결제완료 Badge
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
                              summary.tableNumber,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(summary.paidTime),
                            style: const TextStyle(
                              color: Color(0xFFEC407A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007A87),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '결제완료',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Content: Aggregated Item List with prices
                      Expanded(
                        child: ListView.builder(
                          itemCount: aggregatedItems.length,
                          itemBuilder: (context, itemIdx) {
                            final item = aggregatedItems[itemIdx];
                            final lineTotal = item.unitPrice * item.quantity;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${item.name} x ${item.quantity}',
                                    style: const TextStyle(
                                      color: Color(0xFFF3C63F),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${NumberFormat('#,##0', 'ko_KR').format(lineTotal)}원',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(color: Color(0xFF2C2E3E), height: 20),
                      // Bottom Footer: 총 금액
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '총 금액',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${NumberFormat('#,##0', 'ko_KR').format(summary.totalAmount)}원',
                            style: const TextStyle(
                              color: Color(0xFFF3C63F),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      );
    }
  }

  void _showTablePaymentDialog(BuildContext context, _TablePaymentSummary summary) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E202C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Table ${summary.tableNumber} 결제하기',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF2C2E3E), height: 24),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '총 결제금액',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,##0', 'ko_KR').format(summary.totalAmount)}원',
                      style: const TextStyle(
                        color: Color(0xFFF3C63F),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
                        label: const Text(
                          '현금결제',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007A87),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showCashPaymentDialog(context, summary);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.credit_card, color: Colors.white, size: 20),
                        label: const Text(
                          '페이결제',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE55A44),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showPayPaymentDialog(context, summary);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPayPaymentDialog(BuildContext context, _TablePaymentSummary summary) {
    final TextEditingController scannerController = TextEditingController();
    final FocusNode scannerFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF1E222B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.credit_card, color: Color(0xFF00A896), size: 24),
                        SizedBox(width: 10),
                        Text(
                          '간편 페이 결제',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Store & Amount Summary Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141720),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('결제 매장', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(
                            _restaurantNameState.isEmpty ? '던킨도넛' : _restaurantNameState,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('결제 금액', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(
                            '${NumberFormat('#,##0', 'ko_KR').format(summary.totalAmount)}원',
                            style: const TextStyle(
                              color: Color(0xFFF3C63F),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Metallic Payment Terminal Graphic Card
                Container(
                  width: double.infinity,
                  height: 200,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1F4A57),
                        Color(0xFF112D36),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PAYMENT TERMINAL',
                            style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600),
                          ),
                          // IC Chip Graphic
                          Container(
                            width: 38,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5B83B),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                      // Center Scanner Icon
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white70,
                        size: 54,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            '스캐너에 바코드를 대주세요',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Icon(
                            Icons.wifi,
                            color: Colors.white38,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle Guidance
                const Text(
                  '스캐너에 페이 바코드(pay계좌번호)를 리딩하면\n자동으로 결제가 완료됩니다.',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Scanner Input Barcode Listener Box
                TextField(
                  controller: scannerController,
                  focusNode: scannerFocusNode,
                  autofocus: true,
                  style: const TextStyle(color: Color(0xFF00A896), fontSize: 14, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '스캐너 입력 대기 중',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF141720),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Color(0xFF00A896)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onSubmitted: (val) async {
                    Navigator.pop(context);
                    await _processTablePayment(summary, '페이결제');
                    if (context.mounted) {
                      showCustomDialog(
                        context: context,
                        title: '페이 결제 완료',
                        content: '간편 페이 결제가 성공적으로 완료되었습니다.',
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                // Tap to simulate payment completion button
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _processTablePayment(summary, '페이결제');
                    if (context.mounted) {
                      showCustomDialog(
                        context: context,
                        title: '페이 결제 완료',
                        content: '간편 페이 결제가 성공적으로 완료되었습니다.',
                      );
                    }
                  },
                  child: const Text('스캔 테스트 (결제 승인)', style: TextStyle(color: Color(0xFF00A896), fontSize: 13)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCashPaymentDialog(BuildContext context, _TablePaymentSummary summary) {
    int receivedAmount = 0;
    final int totalAmount = summary.totalAmount;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int changeAmount = receivedAmount >= totalAmount ? (receivedAmount - totalAmount) : 0;
            final int deficitAmount = receivedAmount < totalAmount ? (totalAmount - receivedAmount) : 0;
            final bool isPayable = receivedAmount >= totalAmount;

            void addCash(int amount) {
              setModalState(() {
                receivedAmount += amount;
              });
            }

            void setExactCash() {
              setModalState(() {
                receivedAmount = totalAmount;
              });
            }

            void clearCash() {
              setModalState(() {
                receivedAmount = 0;
              });
            }

            return Dialog(
              backgroundColor: const Color(0xFF1E202C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 520,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '현금 결제 (Table ${summary.tableNumber})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF2C2E3E), height: 20),
                    const SizedBox(height: 10),

                    // Summary Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2E3E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('총 결제금액', style: TextStyle(color: Colors.white70, fontSize: 15)),
                              Text(
                                '${NumberFormat('#,##0', 'ko_KR').format(totalAmount)}원',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('받은 금액', style: TextStyle(color: Colors.white70, fontSize: 15)),
                              Text(
                                '${NumberFormat('#,##0', 'ko_KR').format(receivedAmount)}원',
                                style: const TextStyle(color: Color(0xFFF3C63F), fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('거스름돈', style: TextStyle(color: Colors.white70, fontSize: 15)),
                              Text(
                                isPayable
                                    ? '${NumberFormat('#,##0', 'ko_KR').format(changeAmount)}원'
                                    : '0원',
                                style: TextStyle(
                                  color: isPayable ? const Color(0xFF2ECC71) : Colors.grey,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (deficitAmount > 0) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '부족 금액: ${NumberFormat('#,##0', 'ko_KR').format(deficitAmount)}원',
                                style: const TextStyle(color: Color(0xFFE55A44), fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Cash Addition Buttons (1000, 5000, 10000, 50000)
                    const Text('빠른 현금 입력', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildCashAddButton('+1,000', () => addCash(1000))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCashAddButton('+5,000', () => addCash(5000))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCashAddButton('+10,000', () => addCash(10000))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildCashAddButton('+50,000', () => addCash(50000))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: Text('단순 전액 (${NumberFormat('#,##0', 'ko_KR').format(totalAmount)}원)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF007A87),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: setExactCash,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('초기화'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: clearCash,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('취소', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPayable ? const Color(0xFF2ECC71) : Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: isPayable
                                ? () async {
                                    Navigator.pop(context);
                                    await _processTablePayment(
                                      summary,
                                      '현금결제',
                                      receivedAmount: receivedAmount,
                                      changeAmount: changeAmount,
                                    );
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(0xFF1E202C),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text('현금 결제 완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('받은 금액:', style: TextStyle(color: Colors.white70)),
                                                  Text('${NumberFormat('#,##0', 'ko_KR').format(receivedAmount)}원', style: const TextStyle(color: Color(0xFFF3C63F), fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  const Text('거스름돈:', style: TextStyle(color: Colors.white70)),
                                                  Text('${NumberFormat('#,##0', 'ko_KR').format(changeAmount)}원', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 22, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A87)),
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('확인', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: Text(
                              isPayable ? '결제 완료' : '금액 부족',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCashAddButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2C2E3E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.white24),
        ),
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _processTablePayment(
    _TablePaymentSummary summary,
    String method, {
    int? receivedAmount,
    int? changeAmount,
  }) async {
    final String paymentId = DateTime.now().millisecondsSinceEpoch.toString();
    final Timestamp now = Timestamp.now();
    for (final ref in summary.orderReferences) {
      final Map<String, dynamic> updateData = {
        'paid': true,
        'completed': true,
        'paymentId': paymentId,
        'paidTime': now,
        'paymentMethod': method,
      };
      if (receivedAmount != null) updateData['receivedAmount'] = receivedAmount;
      if (changeAmount != null) updateData['changeAmount'] = changeAmount;
      await ref.update(updateData);
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

class _TablePaymentSummary {
  final String tableNumber;
  final Map<String, _AggregatedItem> items = {};
  final List<DocumentReference> orderReferences = [];
  int totalAmount = 0;

  _TablePaymentSummary(this.tableNumber);
}

class _PaidTransactionSummary {
  final String paymentId;
  final String tableNumber;
  final DateTime paidTime;
  final Map<String, _AggregatedItem> items = {};
  final List<DocumentReference> orderReferences = [];
  int totalAmount = 0;

  _PaidTransactionSummary({
    required this.paymentId,
    required this.tableNumber,
    required this.paidTime,
  });
}

class _AggregatedItem {
  final String name;
  int quantity;
  int unitPrice;

  _AggregatedItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });
}
