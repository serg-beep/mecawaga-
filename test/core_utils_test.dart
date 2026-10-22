import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mecawaga/core/utils/access_code_utils.dart';
import 'package:mecawaga/core/utils/formatters.dart';
import 'package:mecawaga/core/utils/opening_hours.dart';
import 'package:mecawaga/core/utils/phone_utils.dart';
import 'package:mecawaga/core/validators/app_validators.dart';
import 'package:mecawaga/core/validators/market_validators.dart';
import 'package:mecawaga/features/proprietaire/domain/mecanicien.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('validateurs communs', () {
    test('refusent les valeurs invalides et acceptent les valeurs attendues', () {
      expect(validateName('A'), isNotNull);
      expect(validateName('Awa'), isNull);
      expect(validateEmail('awa'), isNotNull);
      expect(validateEmail('awa@mecawaga.com'), isNull);
      expect(validatePassword('secret'), isNotNull);
      expect(validatePassword('secret123'), isNull);
      expect(validateKilometrage('-1'), isNotNull);
      expect(validateKilometrage('1200'), isNull);
      expect(validateMarketTitle('abc'), isNotNull);
      expect(validateMarketTitle('Casque integral'), isNull);
    });
  });

  group('formatage', () {
    test('formate les prix en FCFA et les dates en francais', () {
      expect(formatFcfa(1500000), '1\u202f500\u202f000 FCFA');
      expect(formatFrenchDate(DateTime(2026, 10, 12)), '12 octobre 2026');
      expect(formatShortFrenchDate(DateTime(2026, 10, 12)), '12 oct. 2026');
    });

    test('calcule les jours restants sans tenir compte de l heure', () {
      final now = DateTime(2026, 10, 12, 23, 30);
      expect(remainingDays(DateTime(2026, 10, 12, 8), now), 0);
      expect(remainingDays(DateTime(2026, 10, 15, 1), now), 3);
      expect(remainingDays(DateTime(2026, 10, 10), now), -2);
    });
  });

  group('telephone Burkina Faso', () {
    test('normalise les numeros locaux et internationaux', () {
      expect(normalizeBurkinaPhoneNumber('70 12 34 56'), '+22670123456');
      expect(normalizeBurkinaPhoneNumber('+226 70 12 34 56'), '+22670123456');
      expect(normalizeBurkinaPhone('+226 78 00 00 00'), '+22678000000');
      expect(() => normalizeBurkinaPhoneNumber('123'), throwsFormatException);
    });
  });

  group('code acces', () {
    test('genere un code au format robuste et sans caracteres ambigus', () {
      final code = generateAccessCode(random: Random(7));

      expect(code, startsWith('MOTO-'));
      expect(isValidAccessCode(code), isTrue);
      expect(validateCodeAcces(code), isNull);
      expect(code.contains(RegExp(r'[01ILO]')), isFalse);
      expect(validateCodeAcces('MOTO-1234'), isNotNull);
    });
  });

  group('horaires atelier', () {
    const hours = {
      1: CreneauJour(ouverture: '08:30', fermeture: '17:30'),
    };

    test('detecte Ouvert maintenant uniquement dans le creneau', () {
      expect(isOpenNow(hours, DateTime(2026, 10, 12, 8, 29)), isFalse);
      expect(isOpenNow(hours, DateTime(2026, 10, 12, 8, 30)), isTrue);
      expect(isOpenNow(hours, DateTime(2026, 10, 12, 17, 29)), isTrue);
      expect(isOpenNow(hours, DateTime(2026, 10, 12, 17, 30)), isFalse);
      expect(isOpenNow(hours, DateTime(2026, 10, 13, 12)), isFalse);
    });
  });
}
