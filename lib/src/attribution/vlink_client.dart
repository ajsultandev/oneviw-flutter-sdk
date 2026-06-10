import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// The vlink attribution endpoint. The project token is sent in the
/// `Authorization` header (Bearer-style) so the backend can route the
/// attribution result to the right project.
const String vlinkEndpoint =
    'https://vlink-node-1-318121223477.us-central1.run.app/api/attribute';

/// Result of an iOS vlink attribution request.
class VlinkResult {
  const VlinkResult({this.params = const {}, this.deepLink, this.ok = false});

  /// Campaign params from the `utm` object in the response.
  final Map<String, String> params;

  /// A top-level `deeplink` from the response, if present.
  final String? deepLink;

  /// Whether the request produced a definitive answer (200 + valid JSON).
  /// Network/transient failures return `ok = false` so the device stays
  /// unmarked and the next cold start can retry.
  final bool ok;
}

/// Requests iOS install attribution from the vlink endpoint.
///
/// The request is sent over a native off-screen `WKWebView` (via the
/// `vlinkAttribute` method-channel call) so it carries WebKit's User-Agent,
/// cookies and TLS — letting vlink correlate it with prior Safari activity.
/// When the native path is unavailable, it falls back to a plain HTTP GET
/// (still a less-rich attribution match, but functional).
class VlinkClient {
  VlinkClient({
    MethodChannel? channel,
    http.Client? httpClient,
  })  : _channel = channel ?? const MethodChannel('oneviw_flutter_sdk'),
        _httpClient = httpClient ?? http.Client();

  final MethodChannel _channel;
  final http.Client _httpClient;

  Future<VlinkResult> attribute(String projectToken) async {
    final authorization = 'Bearer $projectToken';

    String? body;
    try {
      // Primary path: native WKWebView.
      body = await _channel.invokeMethod<String>('vlinkAttribute', {
        'url': vlinkEndpoint,
        'authorization': authorization,
      });
    } on MissingPluginException {
      // No native handler on this platform — fall through to plain HTTP.
      body = null;
    } on PlatformException {
      // The WKWebView attempted the request and failed (timeout / navigation /
      // in-page fetch error). Treat as transient: do NOT fall back to HTTP and
      // do NOT mark attributed. A low-fidelity HTTP organic answer here would
      // otherwise stick and prevent a retry of the high-fidelity WebView path.
      return const VlinkResult(ok: false);
    }

    if (body == null) {
      try {
        final res = await _httpClient.get(
          Uri.parse(vlinkEndpoint),
          headers: {'Authorization': authorization},
        );
        if (res.statusCode < 200 || res.statusCode >= 300) {
          return const VlinkResult(ok: false);
        }
        body = res.body;
      } catch (_) {
        // Network/transient error — don't mark attributed; allow retry.
        return const VlinkResult(ok: false);
      }
    }

    return _parse(body);
  }

  VlinkResult _parse(String body) {
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      // 200 with a garbage body — treat as transient, not "attributed empty".
      return const VlinkResult(ok: false);
    }
    if (json is! Map) return const VlinkResult(ok: false);

    final deeplinkRaw = json['deeplink'];
    final deepLink =
        (deeplinkRaw is String && deeplinkRaw.isNotEmpty) ? deeplinkRaw : null;

    final attributed = json['attributed'] == true;
    final utm = json['utm'];
    if (!attributed || utm is! Map) {
      // Valid response, no match => attributed-as-organic; safe to mark.
      return VlinkResult(deepLink: deepLink, ok: true);
    }

    final params = <String, String>{};
    utm.forEach((k, v) {
      if (k is String && v != null) params[k] = v.toString();
    });
    return VlinkResult(params: params, deepLink: deepLink, ok: true);
  }
}
