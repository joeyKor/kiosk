import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kiosk/models/menu_item.dart';
import 'package:kiosk/shopping_cart.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if there are active (uncompleted) orders for the table.
  Future<bool> checkActiveOrderHistory(String restaurantName, String tableNumber) async {
    if (restaurantName.isEmpty || tableNumber.isEmpty) return false;

    final snapshot = await _firestore
        .collection('orders')
        .where('restaurantName', isEqualTo: restaurantName)
        .where('tableNumber', isEqualTo: tableNumber)
        .where('completed', isEqualTo: false)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Load categories and menu items for a restaurant.
  /// If it is '조이김밥' and empty, initialize with default menu.
  Future<Map<String, dynamic>> loadCategoriesAndMenu(String restaurantName) async {
    if (restaurantName.isEmpty) {
      return {'categories': <String>[], 'menuItems': <String, List<MenuItem>>{}};
    }

    final restaurantRef = _firestore.collection('restaurants').doc(restaurantName);
    final docSnapshot = await restaurantRef.get();

    List<String> categories = [];
    if (docSnapshot.exists && docSnapshot.data()!.containsKey('categories')) {
      categories = List<String>.from(docSnapshot.data()!['categories']);
    }

    final menuItemsSnapshot = await restaurantRef.collection('menuItems').get();
    final Map<String, List<MenuItem>> menuItems = {};

    for (final doc in menuItemsSnapshot.docs) {
      final item = MenuItem.fromJson(doc.data());
      if (menuItems.containsKey(item.category)) {
        menuItems[item.category]!.add(item);
      } else {
        menuItems[item.category] = [item];
      }
    }

    // Default initialization for '조이김밥' if empty
    if (restaurantName == '조이김밥' && (categories.isEmpty || menuItemsSnapshot.docs.isEmpty)) {
      categories = ['김밥', '분식', '음료'];
      await restaurantRef.set({'categories': categories}, SetOptions(merge: true));

      final defaultItems = [
        MenuItem(name: '조이김밥', category: '김밥', price: 3500, description: '정갈하고 든든한 기본 야채 김밥', image: 'assets/images/joy_gimbap.png', order: 1),
        MenuItem(name: '참치김밥', category: '김밥', price: 4500, description: '참치마요를 듬뿍 넣어 부드러운 김밥', image: 'assets/images/tuna_gimbap.png', order: 2),
        MenuItem(name: '치즈김밥', category: '김밥', price: 4200, description: '부드러운 체다치즈가 들어간 고소한 김밥', image: 'assets/images/cheese_gimbap.png', order: 3),
        MenuItem(name: '김치김밥', category: '김밥', price: 4200, description: '매콤 칼칼한 김치가 아삭 씹히는 김밥', image: 'assets/images/kimchi_gimbap.png', isNew: true, order: 4),
        MenuItem(name: '돈가스김밥', category: '김밥', price: 4800, description: '바삭하고 두툼한 돈가스가 들어간 김밥', image: 'assets/images/tonkatsu_gimbap.png', isBest: true, order: 5),
        MenuItem(name: '스팸김밥', category: '김밥', price: 4500, description: '짭조름하고 고소한 스팸이 듬뿍 들어간 김밥', image: 'assets/images/spam_gimbap.png', order: 6),

        MenuItem(name: '국물떡볶이', category: '분식', price: 5000, description: '매콤달콤한 국물 떡볶이', image: 'assets/images/tteokbokki.png', isBest: true, order: 1),
        MenuItem(name: '모듬튀김', category: '분식', price: 4500, description: '바삭하게 튀겨낸 다양한 튀김', image: 'assets/images/fried_platter.png', order: 2),
        MenuItem(name: '찰순대', category: '분식', price: 4000, description: '쫄깃하고 맛있는 전통 순대', image: 'assets/images/soondae.png', order: 3),

        MenuItem(name: '콜라', category: '음료', price: 2000, description: '시원한 캔 콜라', image: 'assets/images/cola.png', order: 1),
        MenuItem(name: '사이다', category: '음료', price: 2000, description: '청량한 캔 사이다', image: 'assets/images/cider.png', order: 2),
        MenuItem(name: '쿨피스', category: '음료', price: 1500, description: '달콤하고 상큼한 쿨피스', image: 'assets/images/coolpis.png', order: 3),
      ];

      final batch = _firestore.batch();
      for (final item in defaultItems) {
        final docRef = restaurantRef.collection('menuItems').doc(item.name);
        batch.set(docRef, item.toJson());
      }
      await batch.commit();

      menuItems.clear();
      for (final item in defaultItems) {
        if (!menuItems.containsKey(item.category)) {
          menuItems[item.category] = [];
        }
        menuItems[item.category]!.add(item);
      }
    }

    return {
      'categories': categories,
      'menuItems': menuItems,
    };
  }

  /// Save updated categories and menu items.
  Future<void> saveCategoriesAndMenu(
    String restaurantName,
    List<String> categories,
    Map<String, List<MenuItem>> menuItems,
  ) async {
    if (restaurantName.isEmpty) {
      throw Exception('음식점 이름이 설정되지 않았습니다.');
    }

    final restaurantRef = _firestore.collection('restaurants').doc(restaurantName);
    final batch = _firestore.batch();

    // Save categories
    batch.set(restaurantRef, {
      'categories': categories,
    }, SetOptions(merge: true));

    // Save menu items
    final menuItemsRef = restaurantRef.collection('menuItems');
    final currentMenuItemsSnapshot = await menuItemsRef.get();
    final currentMenuItemIds = currentMenuItemsSnapshot.docs.map((doc) => doc.id).toSet();
    final updatedMenuItemNames = <String>{};

    for (final category in categories) {
      if (menuItems[category] == null) continue;
      for (final item in menuItems[category]!) {
        final menuItemDocRef = menuItemsRef.doc(item.name);
        batch.set(menuItemDocRef, item.toJson());
        updatedMenuItemNames.add(item.name);
      }
    }

    // Delete removed menu items
    final itemsToDelete = currentMenuItemIds.difference(updatedMenuItemNames);
    for (final itemId in itemsToDelete) {
      batch.delete(menuItemsRef.doc(itemId));
    }

    await batch.commit();
  }

  /// Submit order to Firestore.
  Future<void> submitOrder({
    required String restaurantName,
    required String tableNumber,
    required double totalPrice,
    required String paymentMethod,
    required List<CartItem> cartItems,
  }) async {
    final orderData = {
      'orderTime': Timestamp.now(),
      'restaurantName': restaurantName,
      'tableNumber': tableNumber,
      'completed': false,
      'items': cartItems
          .map(
            (cartItem) => {
              'name': cartItem.item.name,
              'quantity': cartItem.quantity,
              'price': cartItem.item.price,
            },
          )
          .toList(),
      'totalPrice': totalPrice,
      'paymentMethod': paymentMethod,
    };

    await _firestore.collection('orders').add(orderData);
  }

  /// Add a staff call request to Firestore.
  Future<void> callStaff(String restaurantName, String tableNumber) async {
    if (restaurantName.isEmpty || tableNumber.isEmpty) {
      throw Exception('음식점 이름과 테이블 번호를 설정해주세요.');
    }

    await _firestore.collection('calls').add({
      'restaurantName': restaurantName,
      'tableNumber': tableNumber,
      'time': Timestamp.now(),
      'confirmed': false,
    });
  }
}
