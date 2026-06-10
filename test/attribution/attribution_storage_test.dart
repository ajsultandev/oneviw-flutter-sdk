import 'package:flutter_test/flutter_test.dart';
import 'package:oneviw_flutter_sdk/src/attribution/attribution_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('isAttributed is false until markAttributed, then true', () async {
    final storage = AttributionStorage('token_a');
    expect(await storage.isAttributed(), isFalse);
    await storage.markAttributed();
    expect(await storage.isAttributed(), isTrue);
  });

  test('attribution flag is namespaced per project token', () async {
    await AttributionStorage('token_a').markAttributed();
    expect(await AttributionStorage('token_b').isAttributed(), isFalse);
  });

  test('takeDeferredDeepLink reads then clears (fire-once)', () async {
    final storage = AttributionStorage('token_a');
    await storage.setDeferredDeepLink('myapp://x?utm_source=g');
    expect(await storage.takeDeferredDeepLink(), 'myapp://x?utm_source=g');
    // Cleared after the first take.
    expect(await storage.takeDeferredDeepLink(), isNull);
  });
}
