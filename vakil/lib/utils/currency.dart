/// Formats a value as "₹1,618.82" — comma-grouped Indian-style thousands,
/// two decimal places. Shared so every screen that shows money agrees.
String formatCurrency(double value) {
  final rounded = value.toStringAsFixed(2);
  final parts = rounded.split('.');
  final whole = parts[0];
  final decimals = parts[1];

  final buffer = StringBuffer();
  final digits = whole.length;
  for (var i = 0; i < digits; i++) {
    final posFromRight = digits - i;
    buffer.write(whole[i]);
    final isLast3 = posFromRight == 4;
    final isEvery2AfterThat = posFromRight > 4 && (posFromRight - 4) % 2 == 0;
    if (i != digits - 1 && (isLast3 || isEvery2AfterThat)) {
      buffer.write(',');
    }
  }
  return '₹$buffer.$decimals';
}

/// Formats a whole-number rupee amount without decimals, e.g. "₹1,000".
String formatCurrencyWhole(num value) {
  final formatted = formatCurrency(value.toDouble());
  return formatted.substring(0, formatted.length - 3);
}

/// Formats a duration in seconds as "mm:ss".
String formatMinutesSeconds(int totalSeconds) {
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
