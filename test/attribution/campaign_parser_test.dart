import 'package:flutter_test/flutter_test.dart';
import 'package:oneviw_flutter_sdk/src/attribution/campaign_keys.dart';
import 'package:oneviw_flutter_sdk/src/attribution/campaign_parser.dart';

void main() {
  group('parseQueryString', () {
    test('parses key=value pairs', () {
      expect(
        parseQueryString('utm_source=google&utm_campaign=spring'),
        {'utm_source': 'google', 'utm_campaign': 'spring'},
      );
    });

    test('treats + as space (x-www-form-urlencoded)', () {
      expect(
        parseQueryString('utm_campaign=spring+sale'),
        {'utm_campaign': 'spring sale'},
      );
    });

    test('decodes %2B as a literal plus, not a space', () {
      expect(
        parseQueryString('utm_term=a%2Bb'),
        {'utm_term': 'a+b'},
      );
    });

    test('percent-decodes values', () {
      expect(
        parseQueryString('utm_content=hello%20world'),
        {'utm_content': 'hello world'},
      );
    });

    test('handles empty and malformed pairs', () {
      expect(parseQueryString(''), <String, String>{});
      expect(parseQueryString('&&'), <String, String>{});
      expect(parseQueryString('flag'), {'flag': ''});
      expect(parseQueryString('=novalue'), <String, String>{});
    });
  });

  group('parseUrlParams (query + fragment)', () {
    test('reads query params', () {
      expect(
        parseUrlParams('myapp://open?utm_source=foo&utm_medium=cpc'),
        containsPair('utm_source', 'foo'),
      );
    });

    test('reads fragment params', () {
      expect(
        parseUrlParams('myapp://open#utm_source=foo'),
        containsPair('utm_source', 'foo'),
      );
    });

    test('query wins over fragment on collision', () {
      final params = parseUrlParams('myapp://open?utm_source=a#utm_source=b');
      expect(params['utm_source'], 'a');
    });

    test('merges distinct query and fragment keys', () {
      final params = parseUrlParams('myapp://open?utm_source=a#utm_campaign=b');
      expect(params, containsPair('utm_source', 'a'));
      expect(params, containsPair('utm_campaign', 'b'));
    });

    test('returns empty for a URL with no params', () {
      expect(parseUrlParams('myapp://product/123'), <String, String>{});
    });
  });

  group('pickCampaignKeys', () {
    test('filters to configured keys, dropping empty/null', () {
      final picked = pickCampaignKeys(
        {'utm_source': 'g', 'utm_medium': '', 'other': 'x'},
        defaultCampaignKeys,
      );
      expect(picked, {'utm_source': 'g'});
    });

    test('coerces non-string values to strings', () {
      final picked = pickCampaignKeys({'utm_source': 42}, ['utm_source']);
      expect(picked, {'utm_source': '42'});
    });
  });

  group('buildInitialPrefixed', () {
    test('prefixes keys with \$initial_', () {
      expect(
        buildInitialPrefixed({'utm_source': 'g', 'utm_medium': 'cpc'}),
        {'\$initial_utm_source': 'g', '\$initial_utm_medium': 'cpc'},
      );
    });
  });
}
