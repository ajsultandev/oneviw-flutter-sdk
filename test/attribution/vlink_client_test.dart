import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oneviw_flutter_sdk/src/attribution/vlink_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('oneviw_flutter_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('parses an attributed response from the native WKWebView path',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'vlinkAttribute');
      final args = call.arguments as Map;
      expect(args['authorization'], 'Bearer phc_123');
      expect(args['url'], vlinkEndpoint);
      return jsonEncode({
        'attributed': true,
        'utm': {'utm_source': 'fb', 'utm_medium': 'cpc'},
        'deeplink': 'myapp://x',
      });
    });

    final result = await VlinkClient().attribute('phc_123');
    expect(result.ok, isTrue);
    expect(result.params, {'utm_source': 'fb', 'utm_medium': 'cpc'});
    expect(result.deepLink, 'myapp://x');
  });

  test('organic response is ok with no params', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => jsonEncode({'attributed': false}),
    );

    final result = await VlinkClient().attribute('phc_123');
    expect(result.ok, isTrue);
    expect(result.params, isEmpty);
    expect(result.deepLink, isNull);
  });

  test('invalid JSON body is treated as transient (ok = false)', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => 'not json');

    final result = await VlinkClient().attribute('phc_123');
    expect(result.ok, isFalse);
  });

  test('falls back to HTTP when the native path returns null', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    final mock = MockClient((req) async {
      expect(req.headers['Authorization'], 'Bearer phc_123');
      return http.Response(
        jsonEncode({
          'attributed': true,
          'utm': {'utm_medium': 'cpc'},
        }),
        200,
      );
    });

    final result = await VlinkClient(httpClient: mock).attribute('phc_123');
    expect(result.ok, isTrue);
    expect(result.params, {'utm_medium': 'cpc'});
  });

  test('HTTP non-2xx response is ok = false', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final mock = MockClient((req) async => http.Response('err', 500));

    final result = await VlinkClient(httpClient: mock).attribute('phc_123');
    expect(result.ok, isFalse);
  });

  test('WKWebView failure (PlatformException) is transient — no HTTP fallback',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'vlink_failed');
    });

    var httpCalled = false;
    final mock = MockClient((req) async {
      httpCalled = true;
      return http.Response('{}', 200);
    });

    final result = await VlinkClient(httpClient: mock).attribute('phc_123');
    expect(result.ok, isFalse, reason: 'must not mark attributed');
    expect(httpCalled, isFalse, reason: 'must not fall back to HTTP');
  });

  test('MissingPluginException falls back to HTTP', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException('no handler');
    });

    final mock = MockClient((req) async {
      expect(req.headers['Authorization'], 'Bearer phc_123');
      return http.Response(
        jsonEncode({
          'attributed': true,
          'utm': {'utm_source': 'g'},
        }),
        200,
      );
    });

    final result = await VlinkClient(httpClient: mock).attribute('phc_123');
    expect(result.ok, isTrue);
    expect(result.params, {'utm_source': 'g'});
  });
}
