String formatMoney(
  num value, {
  required String symbol,
  int fractionDigits = 2,
}) {
  final fixed = value.abs().toStringAsFixed(fractionDigits);
  final parts = fixed.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final fraction = fractionDigits == 0 ? '' : '.${parts[1]}';
  final sign = value < 0 ? '-' : '';
  return '$sign$symbol$grouped$fraction';
}
