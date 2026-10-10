import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/analytics_range.dart';

export '../domain/analytics_range.dart';

final analyticsRangeProvider =
    NotifierProvider<AnalyticsRangeNotifier, AnalyticsRange>(
      AnalyticsRangeNotifier.new,
    );

class AnalyticsRangeNotifier extends Notifier<AnalyticsRange> {
  @override
  AnalyticsRange build() => AnalyticsRange.day;

  void setRange(AnalyticsRange range) {
    state = range;
  }
}
