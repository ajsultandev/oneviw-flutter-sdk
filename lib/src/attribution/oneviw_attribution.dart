import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:meta/meta.dart';

import 'attribution_storage.dart';
import 'campaign_parser.dart';
import 'install_referrer.dart';
import 'vlink_client.dart';

/// Event names emitted by the attribution layer.
const String _eventAttributed = 'Application Attributed';
const String _eventDeepLink = 'Application Deep Link';

/// The subset of analytics operations the attribution layer needs. OneViw
/// provides an adapter over its engine so this module stays decoupled from
/// the underlying analytics package (and avoids a circular import).
abstract class AttributionAnalytics {
  Future<bool> isOptOut();
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  });
  Future<void> register(String key, Object value);
  Future<void> unregister(String key);
  Future<void> flush();
}

/// Configuration for the attribution layer, derived from [OneViwConfig].
class AttributionConfig {
  AttributionConfig({
    required this.projectToken,
    required this.campaignKeys,
    this.registerCampaignSuperProperties = true,
    this.onDeferredDeepLink,
  });

  final String projectToken;
  final List<String> campaignKeys;
  final bool registerCampaignSuperProperties;
  final void Function(String url)? onDeferredDeepLink;
}

/// Orchestrates install attribution and deep-link campaign capture.
///
/// Ported from the OneViw React Native SDK. Flow on [start]:
///   1. Deliver any deferred deep link persisted by a previous launch.
///   2. Run install attribution (Android Play Install Referrer / iOS vlink),
///      emitting `Application Attributed` when campaign params are found and
///      surfacing any deferred deep link.
///   3. Enable deep-link capture: emit `Application Deep Link` for the cold-
///      start link and every subsequent link.
///
/// Install attribution runs *before* deep-link capture so a cold-start deep
/// link doesn't race the install referrer/vlink lookup.
///
/// Known divergence from web/RN: `posthog_flutter` exposes no session-reset
/// API, so this layer does not rotate the session on attribution events.
/// Campaign params are attached as persistent super-properties (when
/// [AttributionConfig.registerCampaignSuperProperties] is true) rather than
/// session-scoped ones.
class OneViwAttribution {
  OneViwAttribution(
    this._analytics,
    this._config, {
    AttributionStorage? storage,
    VlinkClient? vlinkClient,
    AppLinks? appLinks,
  })  : _storage = storage ?? AttributionStorage(_config.projectToken),
        _vlink = vlinkClient ?? VlinkClient(),
        _appLinks = appLinks ?? AppLinks();

  final AttributionAnalytics _analytics;
  final AttributionConfig _config;
  final AttributionStorage _storage;
  final VlinkClient _vlink;
  final AppLinks _appLinks;

  bool _started = false;
  bool _readyForDeepLinks = false;
  StreamSubscription<Uri>? _sub;

  /// Begin attribution. Idempotent and a no-op on unsupported platforms or
  /// when the user is opted out.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (await _analytics.isOptOut()) return;

    await _fireAndClearDeferredDeepLink();
    await _runInstallAttribution();

    _readyForDeepLinks = true;
    _subscribeDeepLinks();
    await _captureInitialLink();
  }

  /// Stop listening for deep links and release resources.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _readyForDeepLinks = false;
  }

  // ---------------------------------------------------------------------------
  // Install attribution
  // ---------------------------------------------------------------------------

  Future<void> _runInstallAttribution() async {
    if (await _storage.isAttributed()) return;
    // Re-check consent after the async storage read.
    if (await _analytics.isOptOut()) return;

    var params = <String, String>{};
    String? deepLink;
    var shouldMarkAttributed = true;

    try {
      if (Platform.isAndroid) {
        final result = await getAndroidInstallReferrer();
        params = result.params;
        deepLink = result.deepLink;
      } else if (Platform.isIOS) {
        final result = await _vlink.attribute(_config.projectToken);
        params = result.params;
        deepLink = result.deepLink;
        shouldMarkAttributed = result.ok;
      }
    } catch (_) {
      shouldMarkAttributed = false;
    }

    // `Application Attributed` only fires when there are campaign params to
    // report; organic installs skip the event but still mark the device below.
    await _captureAttribution(params);

    if (deepLink != null) {
      await _storage.setDeferredDeepLink(deepLink);
      await _fireAndClearDeferredDeepLink();
    }

    // Only mark attributed on a definitive answer so transient failures retry
    // on the next cold start.
    if (shouldMarkAttributed) {
      await _storage.markAttributed();
    }
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Test seam for the `Application Attributed` event assembly. Platform-gated
  /// install attribution can't run on the host VM, so tests drive this directly.
  @visibleForTesting
  Future<void> captureAttributionForTesting(Map<String, Object?> rawParams) =>
      _captureAttribution(rawParams);

  /// Test seam for the `Application Deep Link` event assembly.
  @visibleForTesting
  Future<void> captureDeepLinkForTesting(String url) => _captureDeepLink(url);

  Future<void> _captureAttribution(Map<String, Object?> rawParams) async {
    if (await _analytics.isOptOut()) return;

    final params = pickCampaignKeys(rawParams, _config.campaignKeys);
    if (params.isEmpty) return;

    final missing =
        _config.campaignKeys.where((k) => !params.containsKey(k)).toList();

    final properties = <String, Object>{...params};
    if (missing.isNotEmpty) properties['\$unset'] = missing;

    await _analytics.capture(
      eventName: _eventAttributed,
      properties: properties,
      userProperties: Map<String, Object>.from(params),
      userPropertiesSetOnce: buildInitialPrefixed(params),
    );

    await _refreshSuperProperties(params);

    // Attribution fires during cold-start handoff — force-flush so the event
    // isn't lost if the app is backgrounded/killed within seconds.
    await _analytics.flush();
  }

  Future<void> _captureDeepLink(String url) async {
    if (await _analytics.isOptOut()) return;

    final params = pickCampaignKeys(parseUrlParams(url), _config.campaignKeys);
    final hasParams = params.isNotEmpty;

    final properties = <String, Object>{'url': url, ...params};
    Map<String, Object>? userProperties;
    Map<String, Object>? userPropertiesSetOnce;

    if (hasParams) {
      final missing =
          _config.campaignKeys.where((k) => !params.containsKey(k)).toList();
      if (missing.isNotEmpty) properties['\$unset'] = missing;
      userProperties = Map<String, Object>.from(params);
      userPropertiesSetOnce = buildInitialPrefixed(params);
    }

    await _analytics.capture(
      eventName: _eventDeepLink,
      properties: properties,
      userProperties: userProperties,
      userPropertiesSetOnce: userPropertiesSetOnce,
    );

    if (hasParams) {
      await _refreshSuperProperties(params);
    }

    await _analytics.flush();
  }

  /// Replace any previously-registered campaign super-properties with the new
  /// ones. Clearing first prevents stale-key leakage when a new deep link
  /// carries a subset of the prior campaign params.
  ///
  /// These are persistent (not session-scoped) — see the class-level note on
  /// the session-reset divergence.
  Future<void> _refreshSuperProperties(Map<String, String> params) async {
    if (!_config.registerCampaignSuperProperties) return;
    for (final key in _config.campaignKeys) {
      await _analytics.unregister(key);
    }
    for (final entry in params.entries) {
      await _analytics.register(entry.key, entry.value);
    }
  }

  // ---------------------------------------------------------------------------
  // Deferred deep links + listeners
  // ---------------------------------------------------------------------------

  Future<void> _fireAndClearDeferredDeepLink() async {
    final handler = _config.onDeferredDeepLink;
    if (handler == null) return;
    final url = await _storage.takeDeferredDeepLink();
    if (url == null) return;
    try {
      handler(url);
    } catch (_) {
      // Handler threw — URL already cleared; apps needing at-least-once
      // delivery should persist it themselves inside the handler.
    }
  }

  void _subscribeDeepLinks() {
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (!_readyForDeepLinks) return;
        _captureDeepLink(uri.toString());
      },
      onError: (_) {},
    );
  }

  Future<void> _captureInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && _readyForDeepLinks) {
        await _captureDeepLink(uri.toString());
      }
    } catch (_) {}
  }
}
