enum TransactionAmountOperator {
  add('+'),
  subtract('−');

  const TransactionAmountOperator(this.symbol);

  final String symbol;
}

class TransactionAmountCalculator {
  String _entry = '0';
  int _runningMinorUnits = 0;
  TransactionAmountOperator? _operator;
  bool _isEnteringOperand = true;

  String get entry => _entry;

  TransactionAmountOperator? get pendingOperator => _operator;

  int get resultMinorUnits {
    final operator = _operator;
    if (operator == null) return _parseMinorUnits(_entry);
    if (!_isEnteringOperand) return _runningMinorUnits;
    return _apply(_runningMinorUnits, _parseMinorUnits(_entry), operator);
  }

  double get result => resultMinorUnits / 100;

  String get displayText {
    final operator = _operator;
    if (operator == null) return _formatMinorUnits(_parseMinorUnits(_entry));

    final left = _formatMinorUnits(_runningMinorUnits);
    if (!_isEnteringOperand) return '$left ${operator.symbol}';
    return '$left ${operator.symbol} ${_formatMinorUnits(_parseMinorUnits(_entry))}';
  }

  void inputDigit(String digit) {
    if (!RegExp(r'^\d$').hasMatch(digit)) return;

    if (!_isEnteringOperand) {
      _entry = '0';
      _isEnteringOperand = true;
    }

    if (_entry == '0') {
      _entry = digit;
      return;
    }

    final decimalIndex = _entry.indexOf('.');
    if (decimalIndex != -1 && _entry.length - decimalIndex > 2) return;
    _entry = '$_entry$digit';
  }

  void inputDecimalPoint() {
    if (!_isEnteringOperand) {
      _entry = '0.';
      _isEnteringOperand = true;
      return;
    }
    if (!_entry.contains('.')) _entry = '$_entry.';
  }

  void backspace() {
    if (!_isEnteringOperand) return;
    _entry = _entry.length > 1 ? _entry.substring(0, _entry.length - 1) : '0';
    if (_entry == '-') _entry = '0';
  }

  void applyOperator(TransactionAmountOperator nextOperator) {
    final currentOperator = _operator;
    if (currentOperator == null) {
      _runningMinorUnits = _parseMinorUnits(_entry);
    } else if (_isEnteringOperand) {
      _runningMinorUnits = _apply(
        _runningMinorUnits,
        _parseMinorUnits(_entry),
        currentOperator,
      );
    }

    _operator = nextOperator;
    _entry = '0';
    _isEnteringOperand = false;
  }

  static int _apply(int left, int right, TransactionAmountOperator operator) {
    return switch (operator) {
      TransactionAmountOperator.add => left + right,
      TransactionAmountOperator.subtract => left - right,
    };
  }

  static int _parseMinorUnits(String value) {
    final parts = value.split('.');
    final whole = int.tryParse(parts.first) ?? 0;
    final decimal = parts.length > 1 ? parts[1] : '';
    final normalizedDecimal = decimal.padRight(2, '0').substring(0, 2);
    return whole * 100 + (int.tryParse(normalizedDecimal) ?? 0);
  }

  static String _formatMinorUnits(int value) {
    final sign = value < 0 ? '-' : '';
    final absolute = value.abs();
    final whole = absolute ~/ 100;
    final decimal = (absolute % 100).toString().padLeft(2, '0');
    return '$sign$whole.$decimal';
  }
}
