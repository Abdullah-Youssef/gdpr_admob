# Migrating from 1.x to 2.0.0

Version 2.0.0 modernizes the UMP flow and intentionally changes the public API.

## SDK requirements

Upgrade the host project to Dart 3.10 and Flutter 3.38.1 or newer, then use:

```yaml
dependencies:
  gdpr_admob: ^2.0.0
  google_mobile_ads: ^9.1.0
```

## Initialization

Before:

```dart
final error = await gdprAdmob.initialize(
  mode: DebugGeography.debugGeographyEea,
  testIdentifiers: ['DEVICE_ID'],
);

if (error != null) {
  print(error.message);
}
```

After, for production:

```dart
final result = await gdprAdmob.initialize();

if (result.canRequestAds) {
  // Load ads.
}

for (final error in result.errors) {
  print(error.message);
}
```

Production calls no longer enable debug geography by default.

## Debug geography

Move test settings into `GdprDebugSettings`:

```dart
final result = await gdprAdmob.initialize(
  configuration: const GdprConfiguration(
    debugSettings: GdprDebugSettings(
      geography: GdprDebugGeography.eea,
      testDeviceIdentifiers: ['UMP_TEST_DEVICE_HASH'],
    ),
  ),
);
```

## Consent status

Before:

```dart
final String status = await gdprAdmob.getConsentStatus();
```

After:

```dart
final GdprConsentStatus status = await gdprAdmob.getConsentStatus();
```

For ad decisions, prefer the result of `initialize()` and check
`result.canRequestAds` instead of checking status alone.

## Reset and privacy options

`resetConsentStatus()` was a testing API. Replace test usage with:

```dart
await gdprAdmob.resetForTesting();
```

For production user choice management, expose a privacy button when required:

```dart
if (result.isPrivacyOptionsRequired) {
  await gdprAdmob.showPrivacyOptionsForm();
}
```

## Apps that own Mobile Ads initialization

Call `requestConsent()` instead of `initialize()`:

```dart
final result = await gdprAdmob.requestConsent();
if (result.canRequestAds) {
  // Initialize the ads SDK or mediation stack.
}
```

## Platform configuration

Verify the AdMob application ID in AndroidManifest.xml and Info.plist. Version
2.0.0 does not inject an application ID into the host app.
