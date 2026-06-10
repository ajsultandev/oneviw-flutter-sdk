import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneviw_flutter_sdk/oneviw_flutter_sdk.dart';
import 'package:oneviw_flutter_sdk/src/oneviw_native_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OneViwConfig.toEngineConfig', () {
    test('maps defaults', () {
      final engine = OneViwConfig('token_abc').toEngineConfig();

      expect(engine.projectToken, 'token_abc');
      expect(engine.host, oneViwDefaultHost);
      expect(engine.flushAt, 20);
      expect(engine.maxQueueSize, 1000);
      expect(engine.maxBatchSize, 50);
      expect(engine.debug, false);
      expect(engine.sessionReplay, false);
      expect(engine.surveys, true);
    });

    test('maps custom values and enums', () {
      final config = OneViwConfig('token_xyz')
        ..host = 'https://custom.oneviw.example'
        ..debug = true
        ..flushAt = 5
        ..sessionReplay = true
        ..personProfiles = OneViwPersonProfiles.always
        ..dataMode = OneViwDataMode.wifi;
      config.sessionReplayConfig
        ..maskAllTexts = false
        ..sampleRate = 0.5;

      final engine = config.toEngineConfig();

      expect(engine.projectToken, 'token_xyz');
      expect(engine.host, 'https://custom.oneviw.example');
      expect(engine.debug, true);
      expect(engine.flushAt, 5);
      expect(engine.sessionReplay, true);
      expect(engine.sessionReplayConfig.maskAllTexts, false);
      expect(engine.sessionReplayConfig.sampleRate, 0.5);
    });
  });

  group('OneViwNativeConfig.readConfig', () {
    const channel = MethodChannel('oneviw_flutter_sdk');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('builds config from native map', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getNativeConfig');
        return <String, Object?>{
          'projectToken': 'native_token',
          'host': 'https://custom.oneviw.example',
          'debug': true,
        };
      });

      final config = await OneViwNativeConfig().readConfig();

      expect(config.projectToken, 'native_token');
      expect(config.host, 'https://custom.oneviw.example');
      expect(config.debug, true);
    });

    test('uses default host when native host is missing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getNativeConfig');
        return <String, Object?>{
          'projectToken': 'native_token',
        };
      });

      final config = await OneViwNativeConfig().readConfig();
      final engine = config.toEngineConfig();

      expect(config.host, isNull);
      expect(engine.host, oneViwDefaultHost);
    });

    test('throws when project token is missing', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return <String, Object?>{};
      });

      expect(
        () => OneViwNativeConfig().readConfig(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
