import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../network/cashlenx_api.dart';

const _compiledBuildDate = String.fromEnvironment('BUILD_DATE');

final artifactBuildDateProvider = Provider<String?>((ref) {
  return normalizeArtifactBuildDate(_compiledBuildDate);
});

final apiReleaseVersionProvider = FutureProvider.autoDispose<String>((
  ref,
) async {
  final response = await ref.watch(cashlenxApiProvider).versionInfo();
  final data = response['data'];
  final version = data is Map ? data['version'] : null;
  if (version is! String || version.trim().isEmpty) {
    throw const FormatException('API version response is missing data.version');
  }
  return version.trim();
}, retry: (_, _) => null);

String? normalizeArtifactBuildDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null ||
      parsed.toUtc().toIso8601String().substring(0, 10) != value) {
    return null;
  }
  return value;
}
