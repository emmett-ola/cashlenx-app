import 'package:cashlenx/features/home/presentation/utils/transaction_filter_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inclusive date range includes both endpoints', () {
    final from = DateTime(2026, 5, 16);
    final to = DateTime(2026, 5, 17);

    expect(
      isWithinInclusiveDateRange(DateTime(2026, 5, 16, 23), from: from, to: to),
      isTrue,
    );
    expect(
      isWithinInclusiveDateRange(DateTime(2026, 5, 17, 23), from: from, to: to),
      isTrue,
    );
    expect(
      isWithinInclusiveDateRange(DateTime(2026, 5, 18), from: from, to: to),
      isFalse,
    );
  });

  test('reversed ranges are invalid and match no dates', () {
    final from = DateTime(2026, 5, 18);
    final to = DateTime(2026, 5, 16);

    expect(isValidInclusiveDateRange(from: from, to: to), isFalse);
    expect(
      isWithinInclusiveDateRange(DateTime(2026, 5, 17), from: from, to: to),
      isFalse,
    );
  });
}
