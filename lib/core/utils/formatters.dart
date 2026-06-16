import 'package:intl/intl.dart';

const kCurrencyCode = 'PKR';
const kCurrencySymbol = 'Rs';

String formatCurrency(double amount, {bool showDecimals = false}) {
  final formatter = NumberFormat.currency(
    locale: 'en_PK',
    symbol: '$kCurrencySymbol ',
    decimalDigits: showDecimals ? 2 : 0,
  );
  return formatter.format(amount);
}

String formatCompactCurrency(double amount) {
  final abs = amount.abs();
  final sign = amount < 0 ? '-' : '';
  if (abs >= 10000000) {
    return '$sign$kCurrencySymbol ${(abs / 10000000).toStringAsFixed(1)}Cr';
  }
  if (abs >= 100000) {
    return '$sign$kCurrencySymbol ${(abs / 100000).toStringAsFixed(0)}L';
  }
  if (abs >= 1000) {
    return '$sign${(abs / 1000).toStringAsFixed(0)}k';
  }
  return '$sign$kCurrencySymbol ${abs.toStringAsFixed(0)}';
}

String formatShortDate(DateTime date) {
  return DateFormat('d MMM').format(date);
}

String formatTime(DateTime date) {
  return DateFormat('h:mm a').format(date);
}

String formatMonthYear(DateTime date) {
  return DateFormat('MMMM yyyy').format(date);
}

String formatShortMonth(DateTime date) {
  return DateFormat('MMM').format(date);
}

String formatPercent(double value) => '${value.toStringAsFixed(0)}%';
