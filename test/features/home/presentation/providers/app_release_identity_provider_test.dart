import 'package:cashlenx/features/home/presentation/providers/app_release_identity_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts only a real artifact date in YYYY-MM-DD form', () {
    expect(normalizeArtifactBuildDate('2026-10-12'), '2026-10-12');
    expect(normalizeArtifactBuildDate('20261012'), isNull);
    expect(normalizeArtifactBuildDate('2026-02-30'), isNull);
    expect(normalizeArtifactBuildDate(''), isNull);
  });
}
