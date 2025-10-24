String simpleDecrypt(String encryptedString) {
  String decryptedString = "";

  // 1️⃣ 숫자 복호화
  for (int i = 0; i < encryptedString.length; i++) {
    String char = encryptedString[i];
    if (RegExp(r'[0-9]').hasMatch(char)) {
      int decryptedDigit = (int.parse(char) - 3 + 10) % 10;
      decryptedString += decryptedDigit.toString();
    } else {
      decryptedString += char; // 숫자가 아니면 그대로 추가
    }
  }

  // 2️⃣ 하이픈(-) 추가 (Python 코드와 동일한 포맷)
  if (decryptedString.length > 11) {
    decryptedString =
        '${decryptedString.substring(0, 3)}-${decryptedString.substring(3, 7)}-${decryptedString.substring(7, 11)}-${decryptedString.substring(11)}';
  }

  return decryptedString;
}
