class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final Map<String, Map<String, String>> _localizedValues = {
    'ko': {
      'welcome_subtitle': '기 다 리 지  말 고 !',
      'welcome_touch': '터치 후',
      'welcome_order': '주문하세요',
      'step_touch': '화면터치',
      'step_select': '상품선택',
      'step_payment': '결제/주문서확인',
      'step_complete': '주문완료',
      'sidebar_order': '메뉴주문',
      'sidebar_fun': 'FUN',
      'sidebar_lang': 'LANG',
      'sidebar_call': '직원\n호출',
      'cart_title': '장바구니',
      'cart_clear': '장바구니 비우기',
      'cart_empty': '장바구니가 비어있습니다.',
      'total_price': '총 금액',
      'order_btn': '주문하기',
      'call_success': '직원을 호출했습니다. 잠시만 기다려주세요.',
      'call_error': '호출 중 오류가 발생했습니다:',
      'setup_required': '음식점 이름과 테이블 번호를 먼저 설정해주세요.',
      'order_history': '주문내역',
      'empty_menu': '메뉴가 없습니다. 설정에서 카테고리와 메뉴를 추가해주세요.',
      'save_complete': '데이터가 성공적으로 저장되었습니다.',
      'save_error': '저장 중 오류가 발생했습니다:',
      'save_fail': '저장 실패',
      'save_fail_no_restaurant': '음식점 이름이 설정되지 않았습니다.',
      'order_error': '주문 처리 중 오류가 발생했습니다:',
      'payment_cash': '현금결제',
      'payment_pay': '페이결제',
      'payment_dialog_title': '결제 수단 선택',
      'payment_dialog_subtitle': '결제 방식을 선택해주세요.',
      'table_select_title': '테이블 번호 선택',
      'table_select_subtitle': '이 기기에서 사용할 테이블 번호를 선택해주세요.',
      'table_unit': '번',
      'table_label': '테이블',
      'cancel': '취소',
      'lang_selection_title': '언어 설정 (Language Settings)',
      'lang_selection_subtitle': '사용하실 언어를 선택해주세요. (Select your language)',
      'fun_winner_title': '🎯 오늘의 벌칙자!',
      'fun_winner_unit': '번',
      'fun_winner_desc': '오늘 식사값은 {winner}번이 쏩니다! 🥳💸',
      'fun_ok': '확인',
      'fun_title': '내기 룰렛 돌리기 🎯',
      'fun_subtitle': '각자 번호를 하나씩 고른 후 SPIN을 눌러 당첨자를 뽑아보세요!',
      'fun_settings': '내기 설정',
      'fun_participants_label': '참여 인원수 설정',
      'fun_participants_unit': '명',
      'fun_rules_title': '진행 규칙 💡',
      'fun_rule_1': '1. 각자 순서대로 1번부터 번호를 하나씩 정합니다.',
      'fun_rule_2': '2. 번호 선정이 끝나면 룰렛을 돌립니다.',
      'fun_rule_3': '3. 화살표가 가리키는 당첨 번호에 배정된 사람이 패배자가 되어 오늘 쏘는 걸로 합니다!',
    },
    'en': {
      'welcome_subtitle': 'Don\'t wait in line!',
      'welcome_touch': 'Touch Here',
      'welcome_order': 'to Order',
      'step_touch': 'Touch Screen',
      'step_select': 'Select Item',
      'step_payment': 'Payment/Check',
      'step_complete': 'Order Done',
      'sidebar_order': 'Order Menu',
      'sidebar_fun': 'FUN',
      'sidebar_lang': 'LANG',
      'sidebar_call': 'Call\nStaff',
      'cart_title': 'Cart',
      'cart_clear': 'Clear Cart',
      'cart_empty': 'Your cart is empty.',
      'total_price': 'Total',
      'order_btn': 'Place Order',
      'call_success': 'Staff has been called. Please wait a moment.',
      'call_error': 'Failed to call staff:',
      'setup_required': 'Please set the restaurant name and table number first.',
      'order_history': 'Order History',
      'empty_menu': 'No items available. Please add categories and menus in settings.',
      'save_complete': 'Data saved successfully.',
      'save_error': 'Error saving data:',
      'save_fail': 'Save Failed',
      'save_fail_no_restaurant': 'Restaurant name is not set.',
      'order_error': 'Error processing order:',
      'payment_cash': 'Cash Payment',
      'payment_pay': 'Pay Payment',
      'payment_dialog_title': 'Select Payment Method',
      'payment_dialog_subtitle': 'Please select a payment method.',
      'table_select_title': 'Select Table Number',
      'table_select_subtitle': 'Please select the table number to use for this device.',
      'table_unit': '',
      'table_label': 'Table',
      'cancel': 'Cancel',
      'lang_selection_title': 'Language Settings',
      'lang_selection_subtitle': 'Please select your preferred language.',
      'fun_winner_title': '🎯 Penalty Winner!',
      'fun_winner_unit': '',
      'fun_winner_desc': 'Player {winner} pays for the meal today! 🥳💸',
      'fun_ok': 'OK',
      'fun_title': 'SPIN THE WHEEL 🎯',
      'fun_subtitle': 'Choose your number and press SPIN to select the winner!',
      'fun_settings': 'Game Settings',
      'fun_participants_label': 'Number of Participants',
      'fun_participants_unit': ' players',
      'fun_rules_title': 'Game Rules 💡',
      'fun_rule_1': '1. Each person chooses a number starting from 1.',
      'fun_rule_2': '2. Press SPIN once everyone has chosen a number.',
      'fun_rule_3': '3. The person whose number is pointed to pays for the meal today!',
    }
  };

  final Map<String, String> _categoriesTranslation = {
    '김밥': 'Gimbap',
    '분식': 'Snacks',
    '음료': 'Drinks',
  };

  final Map<String, Map<String, String>> _menuTranslation = {
    '조이김밥': {'name': 'Joy Gimbap', 'desc': 'Neat and hearty basic vegetable gimbap'},
    '참치김밥': {'name': 'Tuna Gimbap', 'desc': 'Soft gimbap filled with tuna mayo'},
    '치즈김밥': {'name': 'Cheese Gimbap', 'desc': 'Savory gimbap with soft cheddar cheese'},
    '김치김밥': {'name': 'Kimchi Gimbap', 'desc': 'Spicy kimchi gimbap with crunchy texture'},
    '돈가스김밥': {'name': 'Tonkatsu Gimbap', 'desc': 'Gimbap with crispy and thick pork cutlet'},
    '스팸김밥': {'name': 'Spam Gimbap', 'desc': 'Savory gimbap with salty spam'},
    '국물떡볶이': {'name': 'Tteokbokki', 'desc': 'Spicy and sweet tteokbokki with soup'},
    '모듬튀김': {'name': 'Assorted Fries', 'desc': 'Assorted crispy deep-fried dishes'},
    '찰순대': {'name': 'Soondae', 'desc': 'Chewy and delicious traditional blood sausage'},
    '콜라': {'name': 'Cola', 'desc': 'Ice-cold canned cola'},
    '사이다': {'name': 'Cider', 'desc': 'Refreshing canned cider'},
    '쿨피스': {'name': 'Coolpis', 'desc': 'Sweet and refreshing Coolpis'},
  };

  /// Translate UI Text
  String translate(String key, String langCode) {
    return _localizedValues[langCode]?[key] ?? key;
  }

  /// Translate Menu Item Name
  String translateMenuItemName(String name, String langCode) {
    if (langCode == 'ko') return name;
    return _menuTranslation[name]?['name'] ?? name;
  }

  /// Translate Menu Item Description
  String translateMenuItemDescription(String description, String name, String langCode) {
    if (langCode == 'ko') return description;
    return _menuTranslation[name]?['desc'] ?? description;
  }

  /// Translate Category
  String translateCategory(String category, String langCode) {
    if (langCode == 'ko') return category;
    return _categoriesTranslation[category] ?? category;
  }
}
