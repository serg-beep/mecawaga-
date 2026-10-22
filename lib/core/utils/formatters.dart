import 'package:intl/intl.dart';

String formatFcfa(int price) =>
    '${NumberFormat.decimalPattern('fr_FR').format(price)} FCFA';

String formatFrenchDate(DateTime date) =>
    DateFormat('d MMMM yyyy', 'fr_FR').format(date);

String formatShortFrenchDate(DateTime date) =>
    DateFormat('d MMM yyyy', 'fr_FR').format(date);

int remainingDays(DateTime targetDate, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
  return target.difference(today).inDays;
}
