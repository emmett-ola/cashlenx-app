import 'package:cashlenx/shared/formatters/money_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats single and multi-character currency symbols', () {
    expect(formatMoney(1234.5, symbol: r'$'), r'$1,234.50');
    expect(formatMoney(1234.5, symbol: r'S$'), r'S$1,234.50');
    expect(formatMoney(-98, symbol: r'Mex$', fractionDigits: 0), r'-Mex$98');
  });

  test('rounds and formats exact minor-unit values', () {
    expect(moneyMinorUnits(12.505, fractionDigits: 2), 1251);
    expect(moneyMinorUnits(12.5, fractionDigits: 0), 13);
    expect(formatMinorUnits(-1, symbol: r'$', fractionDigits: 2), r'-$0.01');
    expect(formatMinorUnits(-1, symbol: '¥', fractionDigits: 0), '-¥1');
    expect(formatMoneyInput(900, fractionDigits: 2), '900.00');
    expect(formatMoneyInput(900.49, fractionDigits: 0), '900');
  });
}
