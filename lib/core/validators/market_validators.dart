import '../utils/formatters.dart';
import '../utils/phone_utils.dart';

String? validateMarketTitle(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 5 || length > 80) {
    return 'Le titre doit contenir entre 5 et 80 caractères.';
  }
  return null;
}

String? validateMarketDescription(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 20 || length > 1000) {
    return 'La description doit contenir entre 20 et 1 000 caractères.';
  }
  return null;
}

String? validateMarketPrice(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  final price = int.tryParse(digits);
  if (price == null || price <= 0) {
    return 'Saisissez un prix entier supérieur à 0 FCFA.';
  }
  return null;
}

String? validateMarketLocation(String? value) {
  if ((value?.trim().length ?? 0) < 2) {
    return 'Saisissez une ville ou un quartier.';
  }
  return null;
}

String? validateBurkinaPhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  final localDigits = digits.startsWith('226') ? digits.substring(3) : digits;
  if (localDigits.length != 8) {
    return 'Saisissez un numéro burkinabè valide à 8 chiffres.';
  }
  return null;
}

String normalizeBurkinaPhone(String value) {
  try {
    return normalizeBurkinaPhoneNumber(value);
  } on FormatException {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final localDigits = digits.startsWith('226') ? digits.substring(3) : digits;
    return '+226$localDigits';
  }
}

String formatPriceInput(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final price = int.tryParse(digits);
  if (price == null) return '';
  return formatFcfa(price).replaceFirst(' FCFA', '');
}
