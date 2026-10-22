String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

String normalizeBurkinaPhoneNumber(String value) {
  final digits = digitsOnly(value);
  final localDigits = digits.startsWith('226') ? digits.substring(3) : digits;
  if (localDigits.length != 8) {
    throw const FormatException('Le numero doit contenir 8 chiffres locaux.');
  }
  return '+226$localDigits';
}
