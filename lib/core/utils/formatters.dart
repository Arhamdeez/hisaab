import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const kCurrencySymbol = 'Rs';

/// Formats a whole-number amount for currency text fields (e.g. `150,000`).
String formatAmountInput(num value) {
  if (value <= 0) return '';
  return NumberFormat('#,##0').format(value);
}

/// Parses comma-separated amount text back to a number.
double? parseAmountInput(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Inserts thousands separators while the user types digits only.
class CommaThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    if (!RegExp(r'^\d+$').hasMatch(digits)) {
      return oldValue;
    }

    final normalized = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final formatted = NumberFormat('#,##0').format(int.parse(normalized));

    final digitsBeforeCursor = newValue.text
        .substring(0, newValue.selection.baseOffset.clamp(0, newValue.text.length))
        .replaceAll(',', '')
        .length;

    var cursor = formatted.length;
    var digitsSeen = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] != ',') digitsSeen++;
      if (digitsSeen >= digitsBeforeCursor) {
        cursor = i + 1;
        break;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }
}

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
