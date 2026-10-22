import 'dart:math';

import '../../features/proprietaire/domain/code_acces.dart';

final RegExp accessCodeRegExp = RegExp(
  '^$codeAccesPrefixe[$codeAccesAlphabet]{$codeAccesLongueur}\$',
);

String generateAccessCode({Random? random}) {
  final rng = random ?? Random.secure();
  final suffix = List.generate(
    codeAccesLongueur,
    (_) => codeAccesAlphabet[rng.nextInt(codeAccesAlphabet.length)],
  ).join();
  return '$codeAccesPrefixe$suffix';
}

bool isValidAccessCode(String code) => accessCodeRegExp.hasMatch(code);
