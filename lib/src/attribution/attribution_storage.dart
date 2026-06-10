import 'package:shared_preferences/shared_preferences.dart';

/// Persists attribution state across launches using [SharedPreferences].
///
/// Two pieces of state, both namespaced by project token so switching projects
/// on the same device re-attributes:
///   * an "already attributed" marker — prevents re-running install attribution
///     (and re-firing `Application Attributed`) on every cold start.
///   * a deferred deep-link URL — surfaced by install attribution but possibly
///     delivered on a later launch if the handler wasn't ready in time.
class AttributionStorage {
  AttributionStorage(this._projectToken);

  final String _projectToken;

  String get _attributedKey => '@oneviw:attributed:$_projectToken';
  String get _deferredLinkKey => '@oneviw:deferredLink:$_projectToken';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// Whether install attribution has already completed for this project.
  Future<bool> isAttributed() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(_attributedKey) != null;
    } catch (_) {
      return false;
    }
  }

  /// Mark install attribution as complete (stores a timestamp).
  Future<void> markAttributed() async {
    try {
      final prefs = await _prefs;
      await prefs.setString(
        _attributedKey,
        DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      // Best-effort: if storage fails the SDK may re-attribute next launch.
    }
  }

  /// Persist a deferred deep-link URL for delivery (possibly next launch).
  Future<void> setDeferredDeepLink(String url) async {
    try {
      final prefs = await _prefs;
      await prefs.setString(_deferredLinkKey, url);
    } catch (_) {}
  }

  /// Read and atomically clear any persisted deferred deep-link URL.
  ///
  /// Clearing before the caller fires its handler is deliberate: a handler
  /// that throws, or the app being killed mid-delivery, should not cause the
  /// same URL to fire again on the next launch.
  Future<String?> takeDeferredDeepLink() async {
    try {
      final prefs = await _prefs;
      final url = prefs.getString(_deferredLinkKey);
      if (url == null) return null;
      await prefs.remove(_deferredLinkKey);
      return url;
    } catch (_) {
      return null;
    }
  }
}
