# OneViw Flutter SDK — example

A minimal app showing both ways to configure OneViw.

## Run it

This folder ships the Dart source only. Generate the platform folders once, then run:

```bash
cd example
flutter create --platforms android,ios .   # scaffolds the android/ ios/ runners
flutter pub get
flutter run
```

## Switching configuration modes

Open `lib/main.dart` and set `useNativeKeys`:

- `useNativeKeys = false` — **Dart config**. Put your token in `projectToken`, then run.
- `useNativeKeys = true` — **Native keys**. Add the meta-data below, then run.

### Android native keys

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data android:name="oneviw.PROJECT_TOKEN" android:value="your_project_token" />
<meta-data android:name="oneviw.HOST"           android:value="https://<your_oneviw_host>" />
<!-- optional -->
<meta-data android:name="oneviw.DEBUG"          android:value="true" />
```

### iOS native keys

In `ios/Runner/Info.plist`:

```xml
<key>oneviw.PROJECT_TOKEN</key>
<string>your_project_token</string>
<key>oneviw.HOST</key>
<string>https://<your_oneviw_host></string>
<!-- optional -->
<key>oneviw.DEBUG</key>
<true/>
```
