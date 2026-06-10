import 'package:flutter_test/flutter_test.dart';
import 'package:oneviw_flutter_sdk/src/attribution/campaign_keys.dart';
import 'package:oneviw_flutter_sdk/src/attribution/oneviw_attribution.dart';

class _CapturedEvent {
  _CapturedEvent(
    this.name,
    this.properties,
    this.userProperties,
    this.userPropertiesSetOnce,
  );
  final String name;
  final Map<String, Object>? properties;
  final Map<String, Object>? userProperties;
  final Map<String, Object>? userPropertiesSetOnce;
}

class _FakeAnalytics implements AttributionAnalytics {
  bool optedOut = false;
  final events = <_CapturedEvent>[];
  final registered = <String, Object>{};
  final unregistered = <String>[];
  int flushes = 0;

  @override
  Future<bool> isOptOut() async => optedOut;

  @override
  Future<void> capture({
    required String eventName,
    Map<String, Object>? properties,
    Map<String, Object>? userProperties,
    Map<String, Object>? userPropertiesSetOnce,
  }) async {
    events.add(_CapturedEvent(
        eventName, properties, userProperties, userPropertiesSetOnce));
  }

  @override
  Future<void> register(String key, Object value) async {
    registered[key] = value;
  }

  @override
  Future<void> unregister(String key) async => unregistered.add(key);

  @override
  Future<void> flush() async => flushes++;
}

OneViwAttribution _build(_FakeAnalytics analytics,
    {bool registerSuper = true}) {
  return OneViwAttribution(
    analytics,
    AttributionConfig(
      projectToken: 'phc_1',
      campaignKeys: defaultCampaignKeys,
      registerCampaignSuperProperties: registerSuper,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Application Attributed', () {
    test('emits event with \$set / \$set_once / \$unset and super-props',
        () async {
      final analytics = _FakeAnalytics();
      await _build(analytics).captureAttributionForTesting(
        {'utm_source': 'fb', 'utm_medium': 'cpc'},
      );

      expect(analytics.events, hasLength(1));
      final e = analytics.events.single;
      expect(e.name, 'Application Attributed');
      expect(e.properties, containsPair('utm_source', 'fb'));
      expect(e.properties, containsPair('utm_medium', 'cpc'));
      expect(
        e.properties!['\$unset'],
        ['utm_campaign', 'utm_content', 'utm_term'],
      );
      expect(e.userProperties, {'utm_source': 'fb', 'utm_medium': 'cpc'});
      expect(e.userPropertiesSetOnce, {
        '\$initial_utm_source': 'fb',
        '\$initial_utm_medium': 'cpc',
      });
      expect(analytics.flushes, 1);

      // Super-properties: cleared for all keys, set for present ones.
      expect(analytics.unregistered, defaultCampaignKeys);
      expect(analytics.registered, {'utm_source': 'fb', 'utm_medium': 'cpc'});
    });

    test('organic install (no params) emits nothing', () async {
      final analytics = _FakeAnalytics();
      await _build(analytics).captureAttributionForTesting({});
      expect(analytics.events, isEmpty);
      expect(analytics.flushes, 0);
    });

    test('opted-out client emits nothing', () async {
      final analytics = _FakeAnalytics()..optedOut = true;
      await _build(analytics)
          .captureAttributionForTesting({'utm_source': 'fb'});
      expect(analytics.events, isEmpty);
    });

    test('registerCampaignSuperProperties=false skips super-props', () async {
      final analytics = _FakeAnalytics();
      await _build(analytics, registerSuper: false)
          .captureAttributionForTesting({'utm_source': 'fb'});
      expect(analytics.events, hasLength(1));
      expect(analytics.registered, isEmpty);
      expect(analytics.unregistered, isEmpty);
    });
  });

  group('Application Deep Link', () {
    test('with UTMs attaches url + campaign props', () async {
      final analytics = _FakeAnalytics();
      await _build(analytics)
          .captureDeepLinkForTesting('myapp://r?utm_source=g&utm_campaign=x');

      final e = analytics.events.single;
      expect(e.name, 'Application Deep Link');
      expect(e.properties,
          containsPair('url', 'myapp://r?utm_source=g&utm_campaign=x'));
      expect(e.properties, containsPair('utm_source', 'g'));
      expect(e.userProperties, {'utm_source': 'g', 'utm_campaign': 'x'});
      expect(e.userPropertiesSetOnce, {
        '\$initial_utm_source': 'g',
        '\$initial_utm_campaign': 'x',
      });
      expect(analytics.flushes, 1);
    });

    test('without UTMs emits only url (no person/super-prop updates)',
        () async {
      final analytics = _FakeAnalytics();
      await _build(analytics).captureDeepLinkForTesting('myapp://product/123');

      final e = analytics.events.single;
      expect(e.name, 'Application Deep Link');
      expect(e.properties, {'url': 'myapp://product/123'});
      expect(e.userProperties, isNull);
      expect(e.userPropertiesSetOnce, isNull);
      expect(analytics.registered, isEmpty);
      expect(analytics.flushes, 1);
    });
  });
}
