import 'package:meta/meta.dart';
import 'package:posthog_flutter/posthog_flutter.dart' as engine;

/// The full result of evaluating a feature flag, including its variant and payload.
///
/// Returned by `OneViw().getFeatureFlagResult(...)`.
class OneViwFeatureFlagResult {
  const OneViwFeatureFlagResult({
    required this.key,
    required this.enabled,
    this.variant,
    this.payload,
  });

  /// The feature flag key.
  final String key;

  /// Whether the flag is enabled for the current user.
  final bool enabled;

  /// The variant key for multivariate flags, or `null` for boolean flags.
  final String? variant;

  /// The JSON payload associated with the flag, if any.
  final Object? payload;

  /// Wraps an underlying engine result. Returns `null` when [result] is `null`.
  @internal
  static OneViwFeatureFlagResult? fromEngine(
    engine.PostHogFeatureFlagResult? result,
  ) {
    if (result == null) {
      return null;
    }
    return OneViwFeatureFlagResult(
      key: result.key,
      enabled: result.enabled,
      variant: result.variant,
      payload: result.payload,
    );
  }
}
