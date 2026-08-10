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

  void _showChangelogDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E202C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.history_edu, color: Color(0xFF007A87)),
            SizedBox(width: 10),
            Text(
              '업데이트 히스토리',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChangelogItem(
                  version: 'v3.19',
                  changes: [
                    '직원 호출 알림창 개선 (스낵바에서 2초 뒤 자동 닫히는 커스텀 다이얼로그로 변경)',
                    '태블릿 기기 USB 이미지 파일 내보내기/가져오기 시 가상 루트 경로 검증 에러 해결',
                  ],
                ),
                const SizedBox(height: 16),
                _buildChangelogItem(
                  version: 'v3.18',
                  changes: [
                    '주문 내역 페이지를 음식 사진 카드가 있는 시각적인 슬라이드 형태로 디자인 대폭 개선',
                    '현금 결제 및 조이페이 결제 시 정밀 영수증 팝업 양식 연동',
                  ],
                ),
                const SizedBox(height: 16),
                _buildChangelogItem(
                  version: 'v3.17',
                  changes: [
                    '조이페이 Firestore 잔액 차감 기능 및 실시간 승인 트랜잭션 연동',
                    '화면 하단 플로팅 버튼과 메뉴 그리드 간의 레이아웃 겹침 오류 해결',
                  ],
                ),
                const SizedBox(height: 16),
                _buildChangelogItem(
                  version: 'v3.10',
                  changes: [
                    '다국어 번역(영어, 중국어, 일어) 지원 탑재',
                    '태블릿 무인 주문 키오스크 초기 버전 안정화 릴리즈',
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인', style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelogItem({required String version, required List<String> changes}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          version,
          style: const TextStyle(color: Color(0xFF007A87), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF12131A),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: changes.map((change) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF007A87), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      change,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
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
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Version & Security)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card 1: 시스템 정보 및 버전
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E202C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2E3E)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.info_outline, color: Color(0xFF007A87), size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          '시스템 버전 정보',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF12131A),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            '현재 빌드 버전',
                                            style: TextStyle(color: Colors.grey, fontSize: 11),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'ver 3.19',
                                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            '배포 상태: 최신 빌드 실행 중',
                                            style: TextStyle(color: Color(0xFF007A87), fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _showChangelogDialog,
                                        icon: const Icon(Icons.history, color: Colors.white, size: 18),
                                        label: const Text('업데이트 히스토리 보기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2C2E3E),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Card 2: 보안 설정
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E202C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2E3E)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.security, color: Color(0xFF2CA05A), size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          '보안 설정',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      '관리자 모드 진입 시 입력하는 PIN 번호를 변경 및 관리합니다.',
                                      style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _changePin,
                                        icon: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
                                        label: const Text('관리자 PIN 번호 변경', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2CA05A),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right Column (Path & Data)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card 3: 저장 경로 설정
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E202C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2E3E)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.folder_open, color: Color(0xFFE5B13A), size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          '메뉴 이미지 저장 경로',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
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
                                        style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'monospace'),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.edit_road, color: Colors.white, size: 18),
                                        label: const Text('저장 폴더 변경', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        onPressed: _pickImageFolder,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF007A87),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Card 4: 데이터 관리 및 복원
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E202C),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2C2E3E)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.storage, color: Color(0xFFE55A44), size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          '데이터 관리 및 초기화',
                                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _deleteOrders(false),
                                        icon: const Icon(Icons.cleaning_services, color: Colors.white, size: 18),
                                        label: const Text('어제까지의 주문/호출 내역 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE55A44),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _deleteOrders(true),
                                        icon: const Icon(Icons.delete_forever, color: Colors.white, size: 18),
                                        label: const Text('모든 주문 및 호출 내역 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFC0222B),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(color: Color(0xFF2C2E3E), thickness: 1),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '기본 제공되는 조이김밥 데모 메뉴 데이터를 설치 초기 상태로 다시 되돌립니다.',
                                      style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.4),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _restoreDefaultJoyGimbap,
                                        icon: const Icon(Icons.restore, color: Colors.white, size: 18),
                                        label: const Text('조이김밥 데모 데이터 복원', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF007A87),
                                          padding: const EdgeInsets.symmetric(vertical: 13),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
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
