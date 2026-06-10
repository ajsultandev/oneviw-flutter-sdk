import 'dart:async';

import 'package:posthog_flutter/posthog_flutter.dart' as engine;

import 'attribution/campaign_keys.dart';
import 'attribution/oneviw_attribution.dart';
import 'oneviw_config.dart';
import 'oneviw_feature_flag_result.dart';
import 'oneviw_native_config.dart';

/// The OneViw client.
///
/// Access the shared instance with `OneViw()` and initialize it once at startup
/// using either [setup] (Dart configuration) or [init] (native `oneviw.*` keys).
///
/// ```dart
/// await OneViw().setup(OneViwConfig('<project_token>'));
/// await OneViw().capture(eventName: 'app_opened');
/// ```
class OneViw {
  OneViw._({OneViwNativeConfig? nativeConfig})
      : _nativeConfig = nativeConfig ?? OneViwNativeConfig();

  static final OneViw _instance = OneViw._();

  /// Returns the shared [OneViw] instance.
  factory OneViw() => _instance;

  final OneViwNativeConfig _nativeConfig;

  engine.Posthog get _engine => engine.Posthog();

  /// Active attribution layer, when enabled. Held so [close] can tear down the
  /// deep-link listener.
  OneViwAttribution? _attribution;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes OneViw from an in-code [OneViwConfig].
  Future<void> setup(OneViwConfig config) async {
    await _engine.setup(config.toEngineConfig());
    _startAttribution(config);
  }

  /// Starts the attribution layer in the background unless disabled. Not
  /// awaited by [setup] so install-referrer/vlink lookups don't block startup.
  void _startAttribution(OneViwConfig config) {
    if (config.disableAttribution) return;
    final previous = _attribution;
    final attribution = OneViwAttribution(
      _EngineAttributionAnalytics(_engine),
      AttributionConfig(
        projectToken: config.projectToken,
        campaignKeys: config.campaignKeys ?? defaultCampaignKeys,
        registerCampaignSuperProperties: config.registerCampaignSuperProperties,
        onDeferredDeepLink: config.onDeferredDeepLink,
      ),
    );
    _attribution = attribution;
    unawaited(() async {
      await previous?.dispose();
      await attribution.start();
    }());
  }

  /// Initializes OneViw from native `oneviw.PROJECT_TOKEN` / `oneviw.HOST` keys
  /// declared in AndroidManifest.xml (Android) or Info.plist (iOS).
  ///
  /// Not supported on web — use [setup] there instead.
  Future<void> init() async {
    final config = await _nativeConfig.readConfig();
    await setup(config);
  }

  // ---------------------------------------------------------------------------
  // Event capture
  // ---------------------------------------------------------------------------

  /// Captures an event named [eventName] with optional [properties].
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) {
    return _engine.capture(
      eventName: eventName,
      properties: properties,
      userProperties: userProperties,
      userPropertiesSetOnce: userPropertiesSetOnce,
    );
  }

  /// Captures a screen view for [screenName].
  ///
  /// Prefer attaching a [OneViwObserver] to your navigator for automatic
  /// screen tracking.
  Future<void> screen({
    required String screenName,
    Map<String, Object>? properties,
  }) {
    return _engine.screen(screenName: screenName, properties: properties);
  }

  // ---------------------------------------------------------------------------
  // Identification
  // ---------------------------------------------------------------------------

  /// Associates the current session with a known [userId].
  Future<void> identify({
    required String userId,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) {
    return _engine.identify(
      userId: userId,
      userProperties: userProperties,
      userPropertiesSetOnce: userPropertiesSetOnce,
    );
  }

  /// Sets properties on the current person.
  Future<void> setPersonProperties({
    Map<String, Object>? userPropertiesToSet,
    Map<String, Object>? userPropertiesToSetOnce,
  }) {
    return _engine.setPersonProperties(
      userPropertiesToSet: userPropertiesToSet,
      userPropertiesToSetOnce: userPropertiesToSetOnce,
    );
  }

  /// Adds an [alias] for the current user's distinct id.
  Future<void> alias({required String alias}) {
    return _engine.alias(alias: alias);
  }

  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  /// Associates the current user with a group.
  Future<void> group({
    required String groupType,
    required String groupKey,
    Map<String, Object>? groupProperties,
  }) {
    return _engine.group(
      groupType: groupType,
      groupKey: groupKey,
      groupProperties: groupProperties,
    );
  }

  // ---------------------------------------------------------------------------
  // Super properties
  // ---------------------------------------------------------------------------

  /// Registers a super property [key] sent with every subsequent event.
  Future<void> register(String key, Object value) {
    return _engine.register(key, value);
  }

  /// Removes a previously registered super property [key].
  Future<void> unregister(String key) {
    return _engine.unregister(key);
  }

  // ---------------------------------------------------------------------------
  // Feature flags
  // ---------------------------------------------------------------------------

  /// Returns whether the feature flag [key] is enabled.
  Future<bool> isFeatureEnabled(String key) {
    return _engine.isFeatureEnabled(key);
  }

  /// Reloads feature flags from the server.
  Future<void> reloadFeatureFlags() {
    return _engine.reloadFeatureFlags();
  }

  /// Returns the value of the feature flag [key] (`bool` or variant `String`).
  Future<Object?> getFeatureFlag(String key) {
    return _engine.getFeatureFlag(key);
  }

  /// Returns the full result (variant + payload) for the feature flag [key].
  Future<OneViwFeatureFlagResult?> getFeatureFlagResult(
    String key, {
    bool sendEvent = true,
  }) async {
    final result =
        await _engine.getFeatureFlagResult(key, sendEvent: sendEvent);
    return OneViwFeatureFlagResult.fromEngine(result);
  }

  /// Returns the JSON payload attached to the feature flag [key].
  @Deprecated(
    'Use getFeatureFlagResult instead, which returns both value and payload.',
  )
  Future<Object?> getFeatureFlagPayload(String key) {
    // ignore: deprecated_member_use
    return _engine.getFeatureFlagPayload(key);
  }

  /// Sets person properties used for flag evaluation.
  Future<void> setPersonPropertiesForFlags(
    Map<String, Object> userProperties, {
    bool reloadFeatureFlags = true,
  }) {
    return _engine.setPersonPropertiesForFlags(
      userProperties,
      reloadFeatureFlags: reloadFeatureFlags,
    );
  }

  /// Clears person properties used for flag evaluation.
  Future<void> resetPersonPropertiesForFlags({bool reloadFeatureFlags = true}) {
    return _engine.resetPersonPropertiesForFlags(
      reloadFeatureFlags: reloadFeatureFlags,
    );
  }

  /// Sets group properties used for flag evaluation.
  Future<void> setGroupPropertiesForFlags(
    String groupType,
    Map<String, Object> groupProperties, {
    bool reloadFeatureFlags = true,
  }) {
    return _engine.setGroupPropertiesForFlags(
      groupType,
      groupProperties,
      reloadFeatureFlags: reloadFeatureFlags,
    );
  }

  /// Clears group properties used for flag evaluation.
  Future<void> resetGroupPropertiesForFlags({
    String? groupType,
    bool reloadFeatureFlags = true,
  }) {
    return _engine.resetGroupPropertiesForFlags(
      groupType: groupType,
      reloadFeatureFlags: reloadFeatureFlags,
    );
  }

  // ---------------------------------------------------------------------------
  // User & session management
  // ---------------------------------------------------------------------------

  /// Returns the current distinct id.
  Future<String> getDistinctId() {
    return _engine.getDistinctId();
  }

  /// Resets the current user, clearing the distinct id and stored state.
  Future<void> reset() {
    return _engine.reset();
  }

  /// Opts the current user out of tracking.
  Future<void> disable() {
    return _engine.disable();
  }

  /// Opts the current user back into tracking.
  Future<void> enable() {
    return _engine.enable();
  }

  /// Returns whether the current user is opted out.
  Future<bool> isOptOut() {
    return _engine.isOptOut();
  }

  /// Returns the current session id, if any.
  Future<String?> getSessionId() {
    return _engine.getSessionId();
  }

  /// Starts session recording. When [resumeCurrent] is `true`, resumes the
  /// current session instead of starting a new one.
  Future<void> startSessionRecording({bool resumeCurrent = true}) {
    return _engine.startSessionRecording(resumeCurrent: resumeCurrent);
  }

  /// Stops session recording.
  Future<void> stopSessionRecording() {
    return _engine.stopSessionRecording();
  }

  /// Returns whether session replay is currently active.
  Future<bool> isSessionReplayActive() {
    return _engine.isSessionReplayActive();
  }

  // ---------------------------------------------------------------------------
  // Exceptions
  // ---------------------------------------------------------------------------

  /// Captures an exception for error tracking.
  Future<void> captureException({
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) {
    return _engine.captureException(
      error: error,
      stackTrace: stackTrace,
      properties: properties,
    );
  }

  // ---------------------------------------------------------------------------
  // Diagnostics & lifecycle
  // ---------------------------------------------------------------------------

  /// Enables or disables verbose debug logging at runtime.
  Future<void> debug(bool enabled) {
    return _engine.debug(enabled);
  }

  /// Flushes any queued events immediately.
  Future<void> flush() {
    return _engine.flush();
  }

  /// Closes the client and releases resources.
  Future<void> close() async {
    await _attribution?.dispose();
    _attribution = null;
    await _engine.close();
  }
}

/// Adapts the underlying engine to the [AttributionAnalytics] surface the
/// attribution layer depends on, keeping that layer decoupled from the engine.
class _EngineAttributionAnalytics implements AttributionAnalytics {
  _EngineAttributionAnalytics(this._engine);

  final engine.Posthog _engine;

  @override
  Future<bool> isOptOut() => _engine.isOptOut();

  @override
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) {
    return _engine.capture(
      eventName: eventName,
      properties: properties,
      userProperties: userProperties,
      userPropertiesSetOnce: userPropertiesSetOnce,
    );
  }

  @override
  Future<void> register(String key, Object value) =>
      _engine.register(key, value);

  @override
  Future<void> unregister(String key) => _engine.unregister(key);

  @override
  Future<void> flush() => _engine.flush();
}
