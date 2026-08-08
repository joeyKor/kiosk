import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiosk/widgets/custom_dialog.dart';
import 'package:kiosk/widgets/pin_dialog.dart';

class RestaurantSetupDialog extends StatefulWidget {
  final Function(String) onSelectRestaurant;

  const RestaurantSetupDialog({
    super.key,
    required this.onSelectRestaurant,
  });

  @override
  State<RestaurantSetupDialog> createState() => _RestaurantSetupDialogState();
}

class _RestaurantSetupDialogState extends State<RestaurantSetupDialog> {
  List<String> _restaurants = [];
  String? _selectedRestaurant;
  bool _isLoading = true;
  final _newRestaurantNameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _newRestaurantNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance.collection('restaurants').get();
      final prefs = await SharedPreferences.getInstance();
      final currentSelected = prefs.getString('restaurantName');

      final list = snapshot.docs.map((doc) => doc.id).toList();

      if (!list.contains('조이김밥')) {
        list.insert(0, '조이김밥');
        await FirebaseFirestore.instance.collection('restaurants').doc('조이김밥').set({
          'categories': ['김밥류', '분식류', '음료/기타'],
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      setState(() {
        _restaurants = list;
        _selectedRestaurant = currentSelected ?? (list.isNotEmpty ? list.first : null);
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading restaurants: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _verifyRestaurantPassword(String restaurantName, String actionTitle) async {
    return await StorePinDialog.show(
      context,
      restaurantName: restaurantName,
      actionTitle: actionTitle,
    );
  }

  Future<void> _showAddRestaurantDialog() async {
    _newRestaurantNameController.clear();
    _passwordController.clear();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2229),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('새 매장 등록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newRestaurantNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: '매장 이름 (예: A김밥집)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF007A87)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: '매장 비밀번호 (숫자 4자리)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF007A87)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007A87),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newName = _newRestaurantNameController.text.trim().replaceAll('/', '_').replaceAll('.', '_');
                final pwd = _passwordController.text.trim();

                if (newName.isEmpty) return;
                if (pwd.length != 4) {
                  showCustomDialog(
                    context: context,
                    title: '입력 오류',
                    content: '매장 비밀번호는 숫자 4자리로 설정해주세요.',
                  );
                  return;
                }

                Navigator.pop(context);
                setState(() {
                  _isLoading = true;
                });

                try {
                  await FirebaseFirestore.instance.collection('restaurants').doc(newName).set({
                    'categories': ['김밥류', '분식류', '음료/기타'],
                    'password': pwd,
                    'createdAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  await _loadRestaurants();
                } catch (e) {
                  print("Error adding restaurant: $e");
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              child: const Text('등록'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E2229),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.45,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '매장 관리 및 선택',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            if (_isLoading)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF007A87))),
              )
            else ...[
              const Text(
                '등록된 매장 목록',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _restaurants.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (context, index) {
                    final name = _restaurants[index];
                    final isSelected = _selectedRestaurant == name;

                    return ListTile(
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            const Icon(Icons.check, color: Color(0xFF007A87), size: 20),
                          if (name != '조이김밥') ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () async {
                                final verified = await _verifyRestaurantPassword(name, '삭제');
                                if (!verified) return;

                                if (!context.mounted) return;

                                // 1. 2차 삭제 재확인 팝업창
                                final bool? confirmDelete = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E2229),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    title: const Text(
                                      '매장 삭제 확인',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    content: Text(
                                      '[$name] 매장을 정말로 삭제하시겠습니까?\n삭제된 매장의 모든 데이터(메뉴 및 설정)는 복구할 수 없습니다.',
                                      style: const TextStyle(color: Colors.white70),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('취소', style: TextStyle(color: Colors.white54)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('삭제하기', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmDelete != true) return;

                                setState(() {
                                  _isLoading = true;
                                });

                                try {
                                  // Delete menuItems first
                                  final docRef = FirebaseFirestore.instance.collection('restaurants').doc(name);
                                  final subcollection = await docRef.collection('menuItems').get();
                                  final batch = FirebaseFirestore.instance.batch();
                                  for (var doc in subcollection.docs) {
                                    batch.delete(doc.reference);
                                  }
                                  batch.delete(docRef);
                                  await batch.commit();

                                  setState(() {
                                    _restaurants.remove(name);
                                    if (_selectedRestaurant == name) {
                                      _selectedRestaurant = null;
                                    }
                                    _isLoading = false;
                                  });

                                  // 2. 삭제 완료 안내 팝업창
                                  if (context.mounted) {
                                    await showCustomDialog(
                                      context: context,
                                      title: '삭제 완료',
                                      content: '[$name] 매장이 삭제되었습니다.',
                                    );
                                  }
                                } catch (e) {
                                  setState(() {
                                    _isLoading = false;
                                  });
                                  if (context.mounted) {
                                    showCustomDialog(
                                      context: context,
                                      title: '삭제 실패',
                                      content: '매장 삭제 중 오류 발생: $e',
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                      onTap: () async {
                        if (_selectedRestaurant == name) return;
                        final verified = await _verifyRestaurantPassword(name, '변경');
                        if (verified) {
                          if (mounted) {
                            Navigator.pop(context, {
                              'restaurantName': name,
                            });
                          }
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add, color: Colors.white70),
                      label: const Text('새 매장 추가', style: TextStyle(color: Colors.white70)),
                      onPressed: _showAddRestaurantDialog,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
