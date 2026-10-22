class Rappel {
  const Rappel({
    required this.id,
    required this.motoId,
    required this.titre,
    required this.date,
    this.remarque,
    this.notificationId,
  });

  final String id;
  final String motoId;
  final String titre;
  final DateTime date;
  final String? remarque;
  final int? notificationId;
}

int notificationIdFor(String rappelId) {
  var hash = 0x811c9dc5;
  for (final unit in rappelId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
