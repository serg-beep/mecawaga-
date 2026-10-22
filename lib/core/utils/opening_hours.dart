import '../../features/proprietaire/domain/mecanicien.dart';

bool isOpenNow(Map<int, CreneauJour> hours, DateTime now) {
  final slot = hours[now.weekday];
  if (slot == null) return false;
  final current = now.hour * 60 + now.minute;
  final opening = _minutes(slot.ouverture);
  final closing = _minutes(slot.fermeture);
  return current >= opening && current < closing;
}

int _minutes(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return 0;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}
