import 'package:flutter/services.dart';

import 'oneviw_config.dart';

/// Reads OneViw configuration from native platform metadata
/// (`oneviw.PROJECT_TOKEN` / `oneviw.HOST` in AndroidManifest.xml or Info.plist).
///
/// This is used by `OneViw().init()`. On platforms without a native manifest
/// (e.g. web), [readConfig] throws and callers should use `OneViw().setup(...)`
/// with a [OneViwConfig] instead.
class OneViwNativeConfig {
  OneViwNativeConfig({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('oneviw_flutter_sdk');

  final MethodChannel _channel;

  /// Reads the native config and builds a [OneViwConfig].
  ///
  /// Throws [StateError] when no project token is configured natively.
  Future<OneViwConfig> readConfig() async {
    final Map<Object?, Object?>? raw =
        await _channel.invokeMethod<Map<Object?, Object?>>('getNativeConfig');

    final String? token = raw?['projectToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError(
        'OneViw could not find a native project token. Define '
        '"oneviw.PROJECT_TOKEN" (and optionally "oneviw.HOST") in your '
        "AndroidManifest.xml / Info.plist, or use OneViw().setup(OneViwConfig(...)) "
        'instead. On web, native keys are not supported — use setup() directly.',
      );
    }

    final config = OneViwConfig(token);

    final String? host = raw?['host'] as String?;
    if (host != null && host.isNotEmpty) {
      config.host = host;
    }

    final bool? debug = raw?['debug'] as bool?;
    if (debug != null) {
      config.debug = debug;
    }

    final bool? disableAttribution = raw?['disableAttribution'] as bool?;
    if (disableAttribution != null) {
      config.disableAttribution = disableAttribution;
    }

    final bool? registerCampaignSuperProperties =
        raw?['registerCampaignSuperProperties'] as bool?;
    if (registerCampaignSuperProperties != null) {
      config.registerCampaignSuperProperties = registerCampaignSuperProperties;
    }

    return config;
  }
}
