import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiosk/widgets/change_pin_dialog.dart';
import 'package:kiosk/widgets/custom_dialog.dart';

class ProgramSettingsPage extends StatefulWidget {
  const ProgramSettingsPage({super.key});

  @override
  State<ProgramSettingsPage> createState() => _ProgramSettingsPageState();
}

class _ProgramSettingsPageState extends State<ProgramSettingsPage> {
  String? _imageFolderPath;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _imageFolderPath = prefs.getString('imageFolderPath');
    });
  }

  Future<void> _pickImageFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('imageFolderPath', selectedDirectory);
      setState(() {
        _imageFolderPath = selectedDirectory;
      });
    }
  }

  Future<void> _changePin() async {
    final newPin = await showDialog<String>(
      context: context,
      builder: (context) => const ChangePinDialog(),
    );

    if (newPin != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('adminPin', newPin);
      showCustomDialog(
        context: context,
        title: '성공',
        content: 'PIN 번호가 변경되었습니다.',
      );
    } else {
      showCustomDialog(
        context: context,
        title: '실패',
        content: 'PIN 번호 변경에 실패했습니다. PIN 번호가 일치하지 않습니다.',
      );
    }
  }

  Future<void> _deleteOrders(bool deleteAll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(deleteAll ? '모든 주문 및 호출 내역을 삭제하시겠습니까?' : '어제까지의 주문 및 호출 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      // Delete orders
      final ordersCollection = FirebaseFirestore.instance.collection('orders');
      Query ordersQuery = ordersCollection;
      if (!deleteAll) {
        ordersQuery = ordersQuery.where('orderTime', isLessThan: Timestamp.fromDate(startOfToday));
      }
      final ordersSnapshot = await ordersQuery.get();
      for (final doc in ordersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete calls
      final callsCollection = FirebaseFirestore.instance.collection('calls');
      Query callsQuery = callsCollection;
      if (!deleteAll) {
        callsQuery = callsQuery.where('time', isLessThan: Timestamp.fromDate(startOfToday));
      }
      final callsSnapshot = await callsQuery.get();
      for (final doc in callsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      showCustomDialog(
        context: context,
        title: '삭제 완료',
        content: deleteAll ? '모든 주문 및 호출 내역이 삭제되었습니다.' : '어제까지의 주문 및 호출 내역이 삭제되었습니다.',
      );
    }
  }

  Future<void> _restoreDefaultJoyGimbap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        title: const Text('복원 확인', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          '기본 데모 매장인 [조이김밥]의 카테고리와 메뉴 데이터를 초기값으로 다시 복원하시겠습니까? (현재 설정된 조이김밥 데이터는 모두 지워지고 초기화됩니다.)',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('복원', style: TextStyle(color: Color(0xFF007A87))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF007A87)),
        ),
      );

      try {
        final restaurantRef = FirebaseFirestore.instance.collection('restaurants').doc('조이김밥');

        final oldMenus = await restaurantRef.collection('menuItems').get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in oldMenus.docs) {
          batch.delete(doc.reference);
        }

        final categories = ['김밥', '분식', '음료'];
        batch.set(restaurantRef, {'categories': categories}, SetOptions(merge: true));

        final defaultItems = [
          { 'name': '조이김밥', 'category': '김밥', 'price': 3500, 'description': '정갈하고 든든한 기본 야채 김밥', 'image': 'assets/images/joy_gimbap.png', 'order': 1 },
          { 'name': '참치김밥', 'category': '김밥', 'price': 4500, 'description': '참치마요를 듬뿍 넣어 부드러운 김밥', 'image': 'assets/images/tuna_gimbap.png', 'order': 2 },
          { 'name': '치즈김밥', 'category': '김밥', 'price': 4200, 'description': '부드러운 체다치즈가 들어간 고소한 김밥', 'image': 'assets/images/cheese_gimbap.png', 'order': 3 },
          { 'name': '김치김밥', 'category': '김밥', 'price': 4200, 'description': '매콤 칼칼한 김치가 아삭 씹히는 김밥', 'image': 'assets/images/kimchi_gimbap.png', 'isNew': true, 'order': 4 },
          { 'name': '돈가스김밥', 'category': '김밥', 'price': 4800, 'description': '바삭하고 두툼한 돈가스가 들어간 김밥', 'image': 'assets/images/tonkatsu_gimbap.png', 'isBest': true, 'order': 5 },
          { 'name': '스팸김밥', 'category': '김밥', 'price': 4500, 'description': '짭조름하고 고소한 스팸이 듬뿍 들어간 김밥', 'image': 'assets/images/spam_gimbap.png', 'order': 6 },
          { 'name': '국물떡볶이', 'category': '분식', 'price': 5000, 'description': '매콤달콤한 국물 떡볶이', 'image': 'assets/images/tteokbokki.png', 'isBest': true, 'order': 1 },
          { 'name': '모듬튀김', 'category': '분식', 'price': 4500, 'description': '바삭하게 튀겨낸 다양한 튀김', 'image': 'assets/images/fried_platter.png', 'order': 2 },
          { 'name': '찰순대', 'category': '분식', 'price': 4000, 'description': '쫄깃하고 맛있는 전통 순대', 'image': 'assets/images/soondae.png', 'order': 3 },
          { 'name': '콜라', 'category': '음료', 'price': 2000, 'description': '시원한 캔 콜라', 'image': 'assets/images/cola.png', 'order': 1 },
          { 'name': '사이다', 'category': '음료', 'price': 2000, 'description': '청량한 캔 사이다', 'image': 'assets/images/cider.png', 'order': 2 },
          { 'name': '쿨피스', 'category': '음료', 'price': 1500, 'description': '달콤하고 상큼한 쿨피스', 'image': 'assets/images/coolpis.png', 'order': 3 },
        ];

        for (final item in defaultItems) {
          final docRef = restaurantRef.collection('menuItems').doc(item['name'] as String);
          batch.set(docRef, item);
        }

        await batch.commit();

        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          showCustomDialog(
            context: context,
            title: '복원 완료',
            content: '기본 매장 [조이김밥]의 메뉴 데이터가 성공적으로 복원되었습니다.',
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Pop loading dialog
          showCustomDialog(
            context: context,
            title: '복원 실패',
            content: '데이터를 복원하는 데 실패했습니다: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1015), // Pitch Dark Background
      body: SafeArea(
        child: Column(
          children: [
            // Dark Header Bar
            Container(
              color: const Color(0xFF12131A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '프로그램 설정 변경',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Exit
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.logout, color: Color(0xFF007A87), size: 18),
                          SizedBox(width: 6),
                          Text(
                            '나가기',
                            style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body Settings Columns
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        // Card 1: 이미지 폴더 설정
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E202C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '이미지 폴더 설정',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF12131A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _imageFolderPath ?? '설정되지 않음',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.folder_open, color: Colors.white),
                                  label: const Text('폴더 변경', style: TextStyle(color: Colors.white)),
                                  onPressed: _pickImageFolder,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007A87),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Card 2: 보안 및 데이터
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E202C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '보안 및 데이터',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _changePin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2CA05A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  child: const Text('PIN 번호 변경'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _deleteOrders(false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE55A44),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  child: const Text('어제까지의 주문내역 삭제'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _deleteOrders(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC0222B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  child: const Text('모든 주문 내역 삭제'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Card 3: 데모 매장 복원
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E202C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '데모 매장 복원',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '기본 데모 매장인 [조이김밥]의 메뉴 데이터를 최초 설치 상태로 다시 복원합니다.',
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _restoreDefaultJoyGimbap,
                                  icon: const Icon(Icons.settings_backup_restore, color: Colors.white, size: 16),
                                  label: const Text('조이김밥 기본 메뉴 복원', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF007A87),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
