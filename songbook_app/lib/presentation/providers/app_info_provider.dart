import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The running build's version, read from the artifact rather than written by
/// hand.
///
/// Settings used to display a hardcoded `'1.0.0'`, which was already wrong and
/// would have gone on being wrong after every release. This reads what was
/// actually built: `pubspec.yaml`'s `version:` for the semantic part, and the
/// build number CI derives from the commit count, so every deployment reports
/// a distinct, increasing value.
///
/// Rendered as `1.1.0 (build 143)`. The build number is the part that tells
/// you whether the page in front of you is the newest deploy or a cached one.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber;
  return build.isEmpty ? info.version : '${info.version} (build $build)';
});
