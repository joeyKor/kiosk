
String simpleDecrypt(String encryptedString) {
  String decryptedString = "";
  for (int i = 0; i < encryptedString.length; i++) {
    String char = encryptedString[i];
    if (char == 'd') {
      decryptedString += '-';
    } else if (int.tryParse(char) != null) {
      int decryptedDigit = (int.parse(char) - 3 + 10) % 10;
      decryptedString += decryptedDigit.toString();
    } else {
      decryptedString += char;
    }
  }
  return decryptedString;
}
