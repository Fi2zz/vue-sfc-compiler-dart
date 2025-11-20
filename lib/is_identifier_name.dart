bool isIdentifierName(String s) {
  if (s.isEmpty) return false;
  bool isFirstValid(int c) {
    final isAlpha = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);
    return isAlpha || c == 95 || c == 36;
  }

  bool isRestValid(int c) {
    final isAlphaNum =
        (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57);
    return isAlphaNum || c == 95 || c == 36;
  }

  final bytes = s.codeUnits;
  if (!isFirstValid(bytes[0])) return false;
  for (var i = 1; i < bytes.length; i++) {
    if (!isRestValid(bytes[i])) return false;
  }
  return true;
}
