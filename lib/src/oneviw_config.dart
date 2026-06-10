import 'package:meta/meta.dart';
import 'package:posthog_flutter/posthog_flutter.dart' as engine;

/// Default OneViw ingestion host used when no host is configured.
const String oneViwDefaultHost = 'https://neons.vroia.com';

/// Controls when OneViw creates person profiles for the users it tracks.
enum OneViwPersonProfiles {
  /// Never create or update a person profile from captured events.
  never,

  /// Create or update a person profile for every captured event.
  always,

  /// Create or update a person profile only after the user has been identified.
  identifiedOnly,
}

/// Controls which network connections OneViw may use to send data.
enum OneViwDataMode {
  /// Only send data over Wi-Fi connections.
  wifi,

  /// Only send data over cellular connections.
  cellular,

  /// Send data over any available connection.
  any,
}

/// Configuration for OneViw session replay (mobile only).
///
/// Session replay is disabled unless [OneViwConfig.sessionReplay] is `true`.
/// Wrap your app in a [OneViwWidget] to capture the screen.
class OneViwSessionReplayConfig {
  OneViwSessionReplayConfig({
    this.maskAllTexts = true,
    this.maskAllImages = true,
    this.throttleDelay = const Duration(seconds: 1),
    this.sampleRate,
  });

  /// Mask all text and text input fields in replays. Defaults to `true`.
  bool maskAllTexts;

  /// Mask all images in replays. Defaults to `true`.
  bool maskAllImages;

  /// Minimum delay between captured snapshots, to limit performance impact.
  Duration throttleDelay;

  /// Sampling rate between 0 and 1. When `null`, the remote configuration is used.
  double? sampleRate;

  /// Translates this config into the underlying engine's representation.
  @internal
  engine.PostHogSessionReplayConfig toEngineConfig() {
    return engine.PostHogSessionReplayConfig()
      ..maskAllTexts = maskAllTexts
      ..maskAllImages = maskAllImages
      ..throttleDelay = throttleDelay
      ..sampleRate = sampleRate;
  }
}

/// Configuration for the [OneViw] client.
///
/// Pass an instance to `OneViw().setup(...)` to initialize the SDK in code.
/// Alternatively, configure native `oneviw.PROJECT_TOKEN` / `oneviw.HOST` keys
/// and call `OneViw().init()` to build this object from those keys automatically.
class OneViwConfig {
  OneViwConfig(this.projectToken);

  /// Your OneViw project token. Required.
  final String projectToken;

  /// Your OneViw ingestion host. When `null`, [oneViwDefaultHost] is used.
  String? host;

  /// Number of queued events that triggers a flush. Defaults to `20`.
  int flushAt = 20;

  /// Maximum number of events kept in the queue. Defaults to `1000`.
  int maxQueueSize = 1000;

  /// Maximum number of events sent in a single batch. Defaults to `50`.
  int maxBatchSize = 50;

  /// Maximum time between automatic flushes. Defaults to 30 seconds.
  Duration flushInterval = const Duration(seconds: 30);

  /// Whether to send a `$feature_flag_called` event when a flag is used.
  /// Defaults to `true`.
  bool sendFeatureFlagEvents = true;

  /// Whether to preload feature flags on startup. Defaults to `true`.
  bool preloadFeatureFlags = true;

  /// Whether to automatically capture application lifecycle events.
  /// Defaults to `true`.
  bool captureApplicationLifecycleEvents = true;

  /// Enable verbose debug logging. Defaults to `false`.
  bool debug = false;

  /// Opt the current user out of tracking on startup. Defaults to `false`.
  bool optOut = false;

  /// When person profiles are created. Defaults to [OneViwPersonProfiles.identifiedOnly].
  OneViwPersonProfiles personProfiles = OneViwPersonProfiles.identifiedOnly;

  /// Enable mobile session replay. Defaults to `false`.
  bool sessionReplay = false;

  /// Fine-grained session replay options. See [OneViwSessionReplayConfig].
  OneViwSessionReplayConfig sessionReplayConfig = OneViwSessionReplayConfig();

  /// Which network connections may be used to send data. Defaults to [OneViwDataMode.any].
  OneViwDataMode dataMode = OneViwDataMode.any;

  /// Enable in-app surveys. Defaults to `true`.
  bool surveys = true;

  // ---------------------------------------------------------------------------
  // Attribution (OneViw-specific; not forwarded to the underlying engine)
  // ---------------------------------------------------------------------------

  /// Disable OneViw's attribution layer (Android install referrer, iOS vlink
  /// attribution, deep-link campaign capture, and the `Application Attributed`
  /// / `Application Deep Link` events). Normal analytics are unaffected.
  /// Defaults to `false`. Also settable via the `oneviw.DISABLE_ATTRIBUTION`
  /// native key.
  bool disableAttribution = false;

  /// UTM-style keys captured from deep links and the install referrer. When
  /// `null`, [defaultCampaignKeys] is used. Pass
  /// `[...defaultCampaignKeys, ...clickIdKeys]` to also capture click IDs.
  List<String>? campaignKeys;

  /// Whether captured campaign params are also registered as persistent
  /// super-properties (attached to subsequent events). Defaults to `true`.
  /// Also settable via the `oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES` native
  /// key.
  bool registerCampaignSuperProperties = true;

  /// Called when install attribution surfaces a deferred deep-link URL (the
  /// `deeplink` value from the install referrer on Android, or the vlink
  /// response on iOS). Fires at most once per persisted URL.
  void Function(String url)? onDeferredDeepLink;

  // NOTE: The underlying engine also supports `onFeatureFlags` and `beforeSend`
  // callbacks. They are intentionally not surfaced here in 1.0.0 to keep the
  // public API independent of the engine's event types. They can be added later
  // with OneViw-owned typedefs if needed.

  /// Translates this config into the underlying engine's representation.
  ///
  /// This is the single point where OneViw configuration maps onto the engine.
  @internal
  engine.PostHogConfig toEngineConfig() {
    final config = engine.PostHogConfig(projectToken)
      ..flushAt = flushAt
      ..maxQueueSize = maxQueueSize
      ..maxBatchSize = maxBatchSize
      ..flushInterval = flushInterval
      ..sendFeatureFlagEvents = sendFeatureFlagEvents
      ..preloadFeatureFlags = preloadFeatureFlags
      ..captureApplicationLifecycleEvents = captureApplicationLifecycleEvents
      ..debug = debug
      ..optOut = optOut
      ..personProfiles = _mapPersonProfiles(personProfiles)
      ..sessionReplay = sessionReplay
      ..sessionReplayConfig = sessionReplayConfig.toEngineConfig()
      ..dataMode = _mapDataMode(dataMode)
      ..surveys = surveys;

    final hostValue = host;
    config.host = hostValue != null && hostValue.isNotEmpty
        ? hostValue
        : oneViwDefaultHost;

    return config;
  }

  static engine.PostHogPersonProfiles _mapPersonProfiles(
    OneViwPersonProfiles value,
  ) {
    switch (value) {
      case OneViwPersonProfiles.never:
        return engine.PostHogPersonProfiles.never;
      case OneViwPersonProfiles.always:
        return engine.PostHogPersonProfiles.always;
      case OneViwPersonProfiles.identifiedOnly:
        return engine.PostHogPersonProfiles.identifiedOnly;
    }
  }

  static engine.PostHogDataMode _mapDataMode(OneViwDataMode value) {
    switch (value) {
      case OneViwDataMode.wifi:
        return engine.PostHogDataMode.wifi;
      case OneViwDataMode.cellular:
        return engine.PostHogDataMode.cellular;
      case OneViwDataMode.any:
        return engine.PostHogDataMode.any;
    }
  }
}
