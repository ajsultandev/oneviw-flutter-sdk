import 'package:flutter/material.dart';
import 'package:oneviw_flutter_sdk/oneviw_flutter_sdk.dart';

// Toggle this to try the two configuration modes:
//  * false -> Dart config (uses the token below).
//  * true  -> Native keys (reads oneviw.PROJECT_TOKEN / oneviw.HOST from the
//             AndroidManifest.xml / Info.plist). Not supported on web.
bool useNativeKeys = false;

// Replace with your OneViw project token when using Dart config mode.
const String projectToken = '<your_project_token>';
// Optional: set your OneViw ingestion host. Leave null to use
// https://neons.vroia.com.
const String? host = null;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (useNativeKeys) {
    // Reads configuration from native oneviw.* keys.
    await OneViw().init();
  } else {
    // Configures everything from Dart.
    final config = OneViwConfig(projectToken)
      ..host = host
      ..debug = true;
    await OneViw().setup(config);
  }

  // Wrap in OneViwWidget so session replay can capture the screen (when enabled).
  runApp(
    const OneViwWidget(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneViw Example',
      navigatorObservers: [OneViwObserver()],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _captureEvent() async {
    await OneViw().capture(
      eventName: 'button_clicked',
      properties: {'source': 'home_page'},
    );
  }

  Future<void> _identify() async {
    await OneViw().identify(
      userId: 'user_123',
      userProperties: {'plan': 'pro'},
    );
  }

  Future<void> _checkFlag(BuildContext context) async {
    final enabled = await OneViw().isFeatureEnabled('new-checkout');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('new-checkout enabled: $enabled')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OneViw Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _captureEvent,
              child: const Text('Capture event'),
            ),
            ElevatedButton(
              onPressed: _identify,
              child: const Text('Identify user'),
            ),
            ElevatedButton(
              onPressed: () => _checkFlag(context),
              child: const Text('Check feature flag'),
            ),
            ElevatedButton(
              onPressed: () => OneViw().reset(),
              child: const Text('Reset user'),
            ),
          ],
        ),
      ),
    );
  }
}
