// Parsing helpers for campaign/UTM extraction from install referrers and
// deep-link URLs. Ported from the OneViw React Native SDK so behaviour
// (precedence, encoding) matches byte-for-byte.

/// Parse an `x-www-form-urlencoded` query string into a flat map.
///
/// In `x-www-form-urlencoded`, `+` represents a space — plain percent-decoding
/// won't do that, so we normalise `+` to `%20` first. A literal `+` that was
/// percent-encoded as `%2B` round-trips correctly: the replace only sees raw
/// `+`, not the encoded form.
Map<String, String> parseQueryString(String query) {
  final out = <String, String>{};
  if (query.isEmpty) return out;

  String decode(String s) {
    try {
      return Uri.decodeComponent(s.replaceAll('+', '%20'));
    } catch (_) {
      return s;
    }
  }

  for (final pair in query.split('&')) {
    if (pair.isEmpty) continue;
    final eq = pair.indexOf('=');
    final rawKey = eq == -1 ? pair : pair.substring(0, eq);
    final rawVal = eq == -1 ? '' : pair.substring(eq + 1);
    if (rawKey.isEmpty) continue;
    out[decode(rawKey)] = decode(rawVal);
  }
  return out;
}

/// Extract params from both the query string and the fragment of [url].
///
/// Some deep-link schemes (e.g. `myapp://open#utm_source=foo`) put campaign
/// data after `#` — particularly when re-using a Universal Link's fragment for
/// the in-app route. Query takes precedence over fragment on key collisions.
Map<String, String> parseUrlParams(String url) {
  // Try Dart's URL parser first; fall back to manual splitting for inputs it
  // can't handle (custom schemes with unusual shapes, etc.).
  try {
    final u = Uri.parse(url);
    final fromQuery = <String, String>{};
    u.queryParameters.forEach((k, v) => fromQuery[k] = v);
    final fromFragment = u.fragment.isNotEmpty
        ? parseQueryString(u.fragment)
        : <String, String>{};
    // Query wins over fragment.
    return <String, String>{...fromFragment, ...fromQuery};
  } catch (_) {
    var rest = url;
    var fragmentPart = '';
    var queryPart = '';

    final hashIdx = rest.indexOf('#');
    if (hashIdx != -1) {
      fragmentPart = rest.substring(hashIdx + 1);
      rest = rest.substring(0, hashIdx);
    }
    final qIdx = rest.indexOf('?');
    if (qIdx != -1) queryPart = rest.substring(qIdx + 1);

    return <String, String>{
      ...parseQueryString(fragmentPart),
      ...parseQueryString(queryPart),
    };
  }
}

/// Keep only the configured campaign [keys] from [params], coercing values to
/// strings and dropping empty/null values.
Map<String, String> pickCampaignKeys(
  Map<String, Object?> params,
  List<String> keys,
) {
  final out = <String, String>{};
  for (final key in keys) {
    final v = params[key];
    if (v == null) continue;
    final s = v.toString();
    if (s.isEmpty) continue;
    out[key] = s;
  }
  return out;
}

/// Build the `$set_once` payload using the standard `$initial_*` prefix, so a
/// team running web + mobile against the same project gets unified property
/// names (`$initial_utm_source`).
Map<String, Object> buildInitialPrefixed(Map<String, String> params) {
  final out = <String, Object>{};
  params.forEach((k, v) => out['\$initial_$k'] = v);
  return out;
}
