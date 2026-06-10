import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart' as engine;

/// Wraps your application so OneViw can capture the screen for session replay.
///
/// Place it at the root of your widget tree, above your `MaterialApp` (or
/// `CupertinoApp`). Session replay is only captured when
/// `OneViwConfig.sessionReplay` is enabled.
///
/// ```dart
/// runApp(
///   OneViwWidget(
///     child: MaterialApp(home: const HomePage()),
///   ),
/// );
/// ```
class OneViwWidget extends StatelessWidget {
  const OneViwWidget({super.key, required this.child});

  /// The widget subtree included in session replay snapshots.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return engine.PostHogWidget(child: child);
  }
}
