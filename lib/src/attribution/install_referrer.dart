import 'dart:async';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';

import 'campaign_parser.dart';

/// Timeout for the Play Install Referrer lookup — if the Play bridge never
/// responds, don't hang attribution forever.
const Duration _androidReferrerTimeout = Duration(seconds: 10);

/// Result of reading the Android Play Install Referrer.
class InstallReferrerResult {
  const InstallReferrerResult({this.params = const {}, this.deepLink});

  /// Parsed query params from the install referrer string.
  final Map<String, String> params;

  /// A `deeplink=` value carried inside the referrer string, if present.
  final String? deepLink;
}

/// Read the Android Play Install Referrer and parse its query string.
///
/// The referrer is a flat `x-www-form-urlencoded` string (e.g.
/// `utm_source=google&utm_campaign=spring+sale`). A `deeplink=` pair, if the
/// marketer included one, is surfaced separately for deferred deep linking.
///
/// Returns an empty result on any failure (no Play Services, sideloaded,
/// emulator, timeout) — treated as a definitive "organic" answer so the SDK
/// doesn't repeat the lookup on every cold start.
Future<InstallReferrerResult> getAndroidInstallReferrer() async {
  try {
    final ReferrerDetails details = await AndroidPlayInstallReferrer
        .installReferrer
        .timeout(_androidReferrerTimeout);

    final referrer = details.installReferrer;
    if (referrer == null || referrer.isEmpty) {
      return const InstallReferrerResult();
    }

    final params = parseQueryString(referrer);
    final deepLink = params['deeplink'];
    return InstallReferrerResult(
      params: params,
      deepLink: (deepLink != null && deepLink.isNotEmpty) ? deepLink : null,
    );
  } catch (_) {
    return const InstallReferrerResult();
  }
}
