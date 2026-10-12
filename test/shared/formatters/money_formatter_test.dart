import 'package:cashlenx/shared/formatters/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats single and multi-character currency symbols', () {
    expect(formatMoney(1234.5, symbol: r'$'), r'$1,234.50');
    expect(formatMoney(1234.5, symbol: r'S$'), r'S$1,234.50');
    expect(formatMoney(-98, symbol: r'Mex$', fractionDigits: 0), r'-Mex$98');
  });
}
