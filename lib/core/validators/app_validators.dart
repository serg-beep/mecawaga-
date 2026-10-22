import '../utils/access_code_utils.dart';

String? validateName(String? value) {
  if ((value?.trim().length ?? 0) < 2) {
    return 'Saisissez au moins 2 caractères.';
  }
  return null;
}

String? validatePhone(String? value) {
  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) {
    return 'Saisissez un numéro de téléphone valide (8 à 15 chiffres).';
  }
  return null;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Saisissez votre adresse e-mail.';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Vérifiez le format, par exemple nom@domaine.fr.';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.length < 8 || !RegExp(r'\d').hasMatch(password)) {
    return 'Le mot de passe doit contenir au moins 8 caractères dont un chiffre.';
  }
  return null;
}

String? validateImmatriculation(String? value) {
  final plate = value?.trim() ?? '';
  if (plate.isEmpty) return 'Saisissez l’immatriculation de la moto.';
  if (!RegExp(r'^[A-Za-z0-9 -]{4,12}$').hasMatch(plate)) {
    return 'Saisissez une immatriculation de 4 à 12 lettres ou chiffres.';
  }
  return null;
}

String? validateKilometrage(
  String? value, {
  int minimum = 0,
  int maximum = 2000000,
}) {
  final kilometre = int.tryParse(value?.trim() ?? '');
  if (kilometre == null || kilometre < minimum || kilometre > maximum) {
    return 'Saisissez un nombre entier entre $minimum et $maximum km.';
  }
  return null;
}

String? validateAnnee(String? value, {int minimum = 1900, int? maximum}) {
  final currentMaximum = maximum ?? DateTime.now().year + 1;
  final year = int.tryParse(value?.trim() ?? '');
  if (year == null || year < minimum || year > currentMaximum) {
    return 'Saisissez une année entre $minimum et $currentMaximum.';
  }
  return null;
}

String? validateCodeAcces(String? value) {
  final code = value?.trim().toUpperCase() ?? '';
  if (!isValidAccessCode(code)) {
    return 'Saisissez le code complet au format MOTO-XXXXXX.';
  }
  return null;
}
