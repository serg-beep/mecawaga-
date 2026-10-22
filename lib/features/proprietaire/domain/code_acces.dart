import 'mecanicien.dart';

const int codeAccesLongueur = 6;
const String codeAccesPrefixe = 'MOTO-';
const String codeAccesAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

class CodeAcces {
  const CodeAcces({
    required this.motoId,
    required this.code,
    required this.expiration,
  });

  final String motoId;
  final String code;
  final DateTime expiration;

  bool get estExpire => !expiration.isAfter(DateTime.now());
}

class AccesMecanicien {
  const AccesMecanicien({
    required this.motoId,
    required this.mecanicien,
    required this.dateAutorisation,
  });

  final String motoId;
  final Mecanicien mecanicien;
  final DateTime dateAutorisation;
}
