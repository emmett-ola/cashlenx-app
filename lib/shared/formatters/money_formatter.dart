String formatMoney(
  num value, {
  required String symbol,
  int fractionDigits = 2,
}) {
  return formatMinorUnits(
    moneyMinorUnits(value, fractionDigits: fractionDigits),
    symbol: symbol,
    fractionDigits: fractionDigits,
  );
}

int moneyMinorUnits(num value, {required int fractionDigits}) {
  assert(fractionDigits >= 0);
  var factor = 1;
  for (var index = 0; index < fractionDigits; index++) {
    factor *= 10;
  }
  return (value * factor).round();
}

String formatMoneyInput(num value, {required int fractionDigits}) {
  assert(fractionDigits >= 0);
  return value.toStringAsFixed(fractionDigits);
}

String formatMinorUnits(
  int minorUnits, {
  required String symbol,
  required int fractionDigits,
}) {
  assert(fractionDigits >= 0);
  var factor = 1;
  for (var index = 0; index < fractionDigits; index++) {
    factor *= 10;
  }

  final absoluteMinorUnits = minorUnits.abs();
  final majorUnits = absoluteMinorUnits ~/ factor;
  final digits = majorUnits.toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) grouped.write(',');
    grouped.write(digits[index]);
  }
  final fraction = fractionDigits == 0
      ? ''
      : '.${(absoluteMinorUnits % factor).toString().padLeft(fractionDigits, '0')}';
  final sign = minorUnits < 0 ? '-' : '';
  return '$sign$symbol$grouped$fraction';
}
