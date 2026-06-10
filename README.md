# OneViw Flutter SDK

`oneviw_flutter_sdk` is the official OneViw analytics & product-insights SDK for Flutter.
Capture events, identify users, evaluate feature flags, record sessions, and track errors —
from a single, simple API.

**Supported platforms:** Android · iOS

---

## ⚠️ Requirements

| Platform | Minimum |
|----------|---------|
| Android  | `minSdkVersion 23` |
| iOS      | platform `13.0` |

Make sure your app meets these **before** installing — the SDK will not build otherwise.

---

## Installation

Add the single dependency to your app's `pubspec.yaml`, then run `flutter pub get`. Choose the
source that matches how you distribute the SDK:

**Local path** (same machine / monorepo):

```yaml
dependencies:
  oneviw_flutter_sdk:
    path: ../1viw-flutter-sdk   # path to this package folder
```

**Git repository:**

```yaml
dependencies:
  oneviw_flutter_sdk:
    git:
      url: https://github.com/ajsultandev/oneviw-flutter-sdk.git
      ref: main
```


---

## Configuration

You can configure OneViw in one of two ways. Pick whichever fits your app.

### Option A — Native keys (Android & iOS)

Declare your credentials in the native app manifests and let OneViw read them for you. Then
call `OneViw().init()` once at startup.

**Android** — `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data android:name="oneviw.PROJECT_TOKEN" android:value="your_project_token" />
<!-- optional -->
<meta-data android:name="oneviw.HOST"          android:value="https://<your_oneviw_host>" />
<meta-data android:name="oneviw.DEBUG"          android:value="true" />
<meta-data android:name="oneviw.DISABLE_ATTRIBUTION" android:value="false" />
<meta-data android:name="oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES" android:value="true" />
```

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>oneviw.PROJECT_TOKEN</key>
<string>your_project_token</string>
<!-- optional -->
<key>oneviw.HOST</key>
<string>https://<your_oneviw_host></string>
<key>oneviw.DEBUG</key>
<true/>
<key>oneviw.DISABLE_ATTRIBUTION</key>
<false/>
<key>oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES</key>
<true/>
```

**Initialize:**

```dart
import 'package:flutter/widgets.dart';
import 'package:oneviw_flutter_sdk/oneviw_flutter_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OneViw().init(); // reads oneviw.PROJECT_TOKEN / oneviw.HOST natively
  runApp(const MyApp());
}
```

If `oneviw.HOST` is omitted, OneViw uses `https://neons.vroia.com`.

### Option B — Dart configuration

Configure everything in code with `OneViwConfig`:

```dart
import 'package:flutter/widgets.dart';
import 'package:oneviw_flutter_sdk/oneviw_flutter_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = OneViwConfig('your_project_token')
    ..host = 'https://<your_oneviw_host>' // optional; defaults to https://neons.vroia.com
    ..debug = true;

  await OneViw().setup(config);
  runApp(const MyApp());
}
```

#### `OneViwConfig` options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `projectToken` | `String` | *(required)* | Your OneViw project token. |
| `host` | `String` | `https://neons.vroia.com` | Your OneViw ingestion host. |
| `flushAt` | `int` | `20` | Queued events that trigger a flush. |
| `maxQueueSize` | `int` | `1000` | Maximum events kept in the queue. |
| `maxBatchSize` | `int` | `50` | Maximum events per network batch. |
| `flushInterval` | `Duration` | `30s` | Maximum time between automatic flushes. |
| `sendFeatureFlagEvents` | `bool` | `true` | Emit an event when a flag is evaluated. |
| `preloadFeatureFlags` | `bool` | `true` | Load feature flags on startup. |
| `captureApplicationLifecycleEvents` | `bool` | `true` | Auto-capture app lifecycle events. |
| `debug` | `bool` | `false` | Verbose debug logging. |
| `optOut` | `bool` | `false` | Start opted out of tracking. |
| `personProfiles` | `OneViwPersonProfiles` | `identifiedOnly` | When person profiles are created. |
| `sessionReplay` | `bool` | `false` | Enable mobile session replay. |
| `sessionReplayConfig` | `OneViwSessionReplayConfig` | *(defaults)* | Replay masking & sampling. |
| `dataMode` | `OneViwDataMode` | `any` | Which connections may send data. |
| `surveys` | `bool` | `true` | Enable in-app surveys. |
| `campaignKeys` | `List<String>?` | *(5 `utm_*` keys)* | UTM keys captured from referrers & deep links. |
| `disableAttribution` | `bool` | `false` | Turn off the attribution layer (see below). |
| `registerCampaignSuperProperties` | `bool` | `true` | Attach captured campaign params as persistent super properties. |
| `onDeferredDeepLink` | `void Function(String)?` | `null` | Called with a deferred deep-link URL surfaced by install attribution. |

---

## Usage

All methods are available on the shared `OneViw()` instance.

### Capture events

```dart
await OneViw().capture(
  eventName: 'user_signed_up',
  properties: {'plan': 'pro', 'referral': 'newsletter'},
);
```

### Identify users

Link the current session to a known user, and optionally attach user properties:

```dart
await OneViw().identify(
  userId: 'user_123',
  userProperties: {'email': 'jane@example.com', 'plan': 'pro'},
  userPropertiesSetOnce: {'first_seen': '2026-06-08'},
);
```

Update person properties later without re-identifying:

```dart
await OneViw().setPersonProperties(
  userPropertiesToSet: {'plan': 'enterprise'},
);
```

Merge an anonymous user into the current identity:

```dart
await OneViw().alias(alias: 'another_distinct_id');
```

### Screen tracking

Track screens automatically by adding `OneViwObserver` to your navigator:

```dart
MaterialApp(
  navigatorObservers: [OneViwObserver()],
  home: const HomePage(),
);
```

With **GoRouter**, add it to the router's observers:

```dart
GoRouter(
  observers: [OneViwObserver()],
  routes: [...],
);
```

Or capture a screen manually:

```dart
await OneViw().screen(
  screenName: 'Checkout',
  properties: {'cart_size': 3},
);
```

### Super properties

Register properties that are automatically attached to every subsequent event:

```dart
await OneViw().register('app_theme', 'dark');
await OneViw().unregister('app_theme');
```

### Feature flags

```dart
// Boolean check
if (await OneViw().isFeatureEnabled('new-checkout')) {
  // show the new checkout
}

// Multivariate value
final variant = await OneViw().getFeatureFlag('pricing-experiment');

// Full result with variant + payload
final result = await OneViw().getFeatureFlagResult('pricing-experiment');
print('${result?.enabled} / ${result?.variant} / ${result?.payload}');

// Force a refresh from the server
await OneViw().reloadFeatureFlags();
```

Influence flag evaluation with person or group properties:

```dart
await OneViw().setPersonPropertiesForFlags({'plan': 'pro'});
await OneViw().resetPersonPropertiesForFlags();

await OneViw().setGroupPropertiesForFlags('company', {'tier': 'enterprise'});
await OneViw().resetGroupPropertiesForFlags(groupType: 'company');
```

### Groups

```dart
await OneViw().group(
  groupType: 'company',
  groupKey: 'company_42',
  groupProperties: {'name': 'Acme Inc', 'tier': 'enterprise'},
);
```

### Session replay (mobile)

Enable replay in your config and wrap your app in `OneViwWidget`:

```dart
final config = OneViwConfig('your_project_token')
  ..sessionReplay = true;
config.sessionReplayConfig
  ..maskAllTexts = true
  ..maskAllImages = true
  ..sampleRate = 0.5; // record 50% of sessions

await OneViw().setup(config);

runApp(
  OneViwWidget(
    child: MaterialApp(home: const HomePage()),
  ),
);
```

Control recording at runtime:

```dart
await OneViw().startSessionRecording();
await OneViw().stopSessionRecording();
final isActive = await OneViw().isSessionReplayActive();
final sessionId = await OneViw().getSessionId();
```

### Error tracking

```dart
try {
  doRiskyThing();
} catch (error, stackTrace) {
  await OneViw().captureException(
    error: error,
    stackTrace: stackTrace,
    properties: {'screen': 'checkout'},
  );
}
```

### Opt-out, reset & flush

```dart
await OneViw().disable();          // opt the user out of tracking
await OneViw().enable();           // opt back in
final isOut = await OneViw().isOptOut();

await OneViw().reset();            // clear the current user/distinct id
await OneViw().flush();            // send queued events immediately

final distinctId = await OneViw().getDistinctId();

// Toggle debug logging at runtime
await OneViw().debug(true);
```

---

## API reference

| Method | Description |
|--------|-------------|
| `setup(OneViwConfig)` | Initialize from a Dart config. |
| `init()` | Initialize from native `oneviw.*` keys (Android/iOS). |
| `capture({eventName, properties, userProperties, userPropertiesSetOnce})` | Capture an event. |
| `screen({screenName, properties})` | Capture a screen view. |
| `identify({userId, userProperties, userPropertiesSetOnce})` | Identify a user. |
| `setPersonProperties({userPropertiesToSet, userPropertiesToSetOnce})` | Update person properties. |
| `alias({alias})` | Add an alias to the current identity. |
| `group({groupType, groupKey, groupProperties})` | Associate the user with a group. |
| `register(key, value)` / `unregister(key)` | Manage super properties. |
| `isFeatureEnabled(key)` | Check a boolean flag. |
| `getFeatureFlag(key)` | Get a flag value/variant. |
| `getFeatureFlagResult(key, {sendEvent})` | Get full flag result (variant + payload). |
| `reloadFeatureFlags()` | Refresh flags from the server. |
| `setPersonPropertiesForFlags(props, {reloadFeatureFlags})` | Set person props for evaluation. |
| `resetPersonPropertiesForFlags({reloadFeatureFlags})` | Clear person props for evaluation. |
| `setGroupPropertiesForFlags(type, props, {reloadFeatureFlags})` | Set group props for evaluation. |
| `resetGroupPropertiesForFlags({groupType, reloadFeatureFlags})` | Clear group props for evaluation. |
| `getDistinctId()` | Get the current distinct id. |
| `reset()` | Reset the current user. |
| `disable()` / `enable()` / `isOptOut()` | Manage tracking opt-out. |
| `getSessionId()` | Get the current session id. |
| `startSessionRecording({resumeCurrent})` / `stopSessionRecording()` | Control session replay. |
| `isSessionReplayActive()` | Whether replay is active. |
| `captureException({error, stackTrace, properties})` | Capture an error. |
| `debug(enabled)` | Toggle debug logging. |
| `flush()` | Send queued events now. |
| `close()` | Close the client and release resources. |

### Widgets & observers

| Symbol | Purpose |
|--------|---------|
| `OneViwWidget` | Root wrapper that enables session replay capture. |
| `OneViwObserver` | `NavigatorObserver` for automatic screen tracking. |

---

## Install attribution & deep links

OneViw automatically attributes installs and captures deep-link campaign data — no
extra code beyond `setup()` / `init()`. It is **on by default**; set
`disableAttribution = true` (or `oneviw.DISABLE_ATTRIBUTION`) to turn the whole layer off.

**How attribution is sourced:**

| Platform | Source |
|----------|--------|
| Android  | Google Play **Install Referrer** (`android_play_install_referrer`). |
| iOS      | OneViw **vlink** endpoint, requested over a hidden native `WKWebView` so it carries WebKit's User-Agent/cookies for accurate correlation (falls back to a plain HTTPS GET). |
| Both     | Incoming **deep links** (initial + while running), via `app_links`. |

Attribution only runs on Android and iOS; it is a no-op on web/desktop. The lookup runs in
the background and does not block `setup()`. Attribution also respects opt-out — while the
user is opted out (`disable()` / `optOut`), no attribution requests or events are sent.

### Receiving deep links

`Application Deep Link` events only fire if your app is actually configured to receive deep
links — OneViw listens for them but the OS must route them to your app first. Add the
platform configuration below (skip it if you don't use deep links).

**Android** — add an `<intent-filter>` to your main `<activity>` in
`android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <!-- custom scheme: myapp://open?utm_source=... -->
  <data android:scheme="myapp" android:host="open" />
</intent-filter>
```

**iOS** — register a custom URL scheme in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>myapp</string></array>
  </dict>
</array>
```

For HTTPS **App Links** (Android) / **Universal Links** (iOS) you'll also need the associated
domain configuration. See the [`app_links` setup guide](https://pub.dev/packages/app_links)
for the full details — OneViw uses `app_links` under the hood, so any setup valid for it works.

### Automatic events

**`Application Attributed`** — fired once per install when campaign params are found
(organic installs emit nothing). **`Application Deep Link`** — fired on every deep-link
open; always includes the `url`, plus campaign params when present.

Both events attach campaign data using the standard OneViw shape:

| Property | Meaning |
|----------|---------|
| `utm_source`, `utm_medium`, … | The captured campaign values (event properties). |
| `$set` | Person properties set to the current campaign values. |
| `$set_once` | First-touch person properties, prefixed `$initial_` (e.g. `$initial_utm_source`). |
| `$unset` | Configured campaign keys absent from this hit. |

When `registerCampaignSuperProperties` is `true` (default), the captured params are also
registered as **persistent super properties**, so subsequent events carry them too.

### Captured keys

By default the five `utm_*` keys are captured (`utm_source`, `utm_medium`, `utm_campaign`,
`utm_content`, `utm_term`). To also capture ad click IDs (`gclid`, `fbclid`, …), opt in:

```dart
final config = OneViwConfig('your_project_token')
  ..campaignKeys = [...defaultCampaignKeys, ...clickIdKeys];
await OneViw().setup(config);
```

### Deferred deep links

If install attribution surfaces a deep-link URL (the `deeplink` value in the Android install
referrer or the iOS vlink response), it is delivered to your handler:

```dart
final config = OneViwConfig('your_project_token')
  ..onDeferredDeepLink = (url) {
    // route the user to the deferred destination
  };
await OneViw().setup(config);
```

The URL is persisted and fires at most once — even if the app is killed before the handler runs.

> **Native-keys init:** `campaignKeys` and `onDeferredDeepLink` are only configurable via
> Dart `setup(OneViwConfig)`. If you initialize with `init()` (native `oneviw.*` keys), you
> still get attribution and the automatic events, but to set these two you must use `setup()`.

### Dependencies

This layer adds: `android_play_install_referrer`, `app_links`, `shared_preferences`, `http`.
They resolve automatically with `oneviw_flutter_sdk`.

---

## License

MIT © OneViw
