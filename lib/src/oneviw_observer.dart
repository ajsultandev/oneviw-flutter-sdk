import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart' as engine;

/// Signature for a function that derives a screen name from [RouteSettings].
///
/// Return `null` to skip tracking a particular route.
typedef OneViwScreenNameExtractor = String? Function(RouteSettings settings);

/// A [NavigatorObserver] that automatically captures screen views as the user
/// navigates.
///
/// Add it to your app's `navigatorObservers` (or your router's `observers`):
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [OneViwObserver()],
///   home: const HomePage(),
/// );
/// ```
class OneViwObserver extends engine.PosthogObserver {
  /// Creates an observer.
  ///
  /// Provide [nameExtractor] to customize how screen names are derived, and
  /// [routeFilter] to decide which routes are tracked. Sensible defaults are
  /// used when omitted.
  OneViwObserver({super.nameExtractor, super.routeFilter});
}
