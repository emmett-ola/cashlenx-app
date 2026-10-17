import 'package:cashlenx/features/home/presentation/utils/transaction_amount_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates a sequence with integer minor units', () {
    final calculator = TransactionAmountCalculator();

    for (final key in ['1', '2']) {
      calculator.inputDigit(key);
    }
    calculator.inputDecimalPoint();
    for (final key in ['5', '0']) {
      calculator.inputDigit(key);
    }
    calculator.applyOperator(TransactionAmountOperator.add);
    calculator.inputDigit('7');
    calculator.inputDecimalPoint();
    calculator.inputDigit('2');
    calculator.inputDigit('5');
    calculator.applyOperator(TransactionAmountOperator.subtract);
    calculator.inputDigit('2');

    expect(calculator.resultMinorUnits, 1775);
    expect(calculator.result, 17.75);
    expect(calculator.displayText, '19.75 − 2.00');
  });

  test('limits operands to two decimal places', () {
    final calculator = TransactionAmountCalculator();

    calculator.inputDigit('1');
    calculator.inputDecimalPoint();
    calculator.inputDigit('2');
    calculator.inputDigit('3');
    calculator.inputDigit('4');

    expect(calculator.entry, '1.23');
    expect(calculator.resultMinorUnits, 123);
  });

  test('replaces consecutive operators and edits only the current operand', () {
    final calculator = TransactionAmountCalculator();

    calculator.inputDigit('9');
    calculator.applyOperator(TransactionAmountOperator.add);
    calculator.applyOperator(TransactionAmountOperator.subtract);
    calculator.backspace();
    calculator.inputDigit('3');
    calculator.backspace();
    calculator.inputDigit('2');

    expect(calculator.pendingOperator, TransactionAmountOperator.subtract);
    expect(calculator.resultMinorUnits, 700);
    expect(calculator.displayText, '9.00 − 2.00');
  });

  test('allows a negative result for validation by the caller', () {
    final calculator = TransactionAmountCalculator();

    calculator.inputDigit('2');
    calculator.applyOperator(TransactionAmountOperator.subtract);
    calculator.inputDigit('5');

    expect(calculator.resultMinorUnits, -300);
    expect(calculator.result, -3);
  });
}
