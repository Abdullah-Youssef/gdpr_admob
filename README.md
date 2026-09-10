# GDPR AdMob

[![pub package](https://img.shields.io/pub/v/gdpr_admob.svg)](https://pub.dev/packages/gdpr_admob)
[![CI](https://github.com/Abdullah-Youssef/gdpr_admob/actions/workflows/ci.yml/badge.svg)](https://github.com/Abdullah-Youssef/gdpr_admob/actions/workflows/ci.yml)

A focused Flutter wrapper for Google's User Messaging Platform (UMP). It
refreshes consent information, presents required consent forms, exposes privacy
options, and initializes Google Mobile Ads only when UMP allows ad requests.

## Features

- Requests fresh consent information on every initialization.
- Uses `loadAndShowConsentFormIfRequired()` for the current UMP flow.
- Checks `canRequestAds()` before initializing Google Mobile Ads.
- Preserves cached consent eligibility when an update fails.
- Supports required privacy options entry points.
- Keeps production and test configuration separate.
- Prevents duplicate concurrent consent and Mobile Ads initialization work.
- Returns typed statuses and structured errors instead of strings.
- Supports global age treatment, content rating, and ad test devices.

## Requirements

- Dart `>=3.10.0 <4.0.0`
- Flutter `>=3.38.1`
- Android and iOS
- `google_mobile_ads ^9.1.0`

## Before you start

1. Add your app to AdMob.
2. In AdMob, open **Privacy & messaging**.
3. Create and publish the messages required for your regions.
4. Add the AdMob application ID to Android and iOS.

UMP displays messages associated with the application ID configured in the
host app. This package cannot create or publish those messages for you.

### Android application ID

Add this inside `<application>` in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy" />
```

### iOS application ID

Add this inside `<dict>` in `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

Follow the current Google Mobile Ads platform setup documentation for any
additional Android or iOS requirements.

## Installation

```yaml
dependencies:
  gdpr_admob: ^2.0.0
  google_mobile_ads: ^9.1.0
```

Declare `google_mobile_ads` directly when your application imports its ad
classes. Do not rely on transitive dependencies.

## Recommended production flow

Keep one manager for the application lifetime and initialize it during app
startup:

```dart
import 'package:gdpr_admob/gdpr_admob.dart';

final gdprAdmob = GdprAdmob();

Future<void> initializeAds() async {
  final result = await gdprAdmob.initialize();

  if (result.hasErrors) {
    for (final error in result.errors) {
      print('${error.stage.name}: ${error.message}');
    }
  }

  if (result.canRequestAds) {
    // Mobile Ads is initialized and ads may now be loaded.
  }

  if (result.isPrivacyOptionsRequired) {
    // Display a persistent "Privacy options" button in your app.
  }
}
```

`initialize()` still checks `canRequestAds()` after consent errors. Google UMP
may permit ads using a valid consent decision from an earlier app session.

## Privacy options

Keep the entry point visible whenever the result requires it:

```dart
Future<void> openPrivacyOptions() async {
  final result = await gdprAdmob.showPrivacyOptionsForm();

  if (result.hasErrors) {
    // Show an appropriate message or log the error.
  }
}
```

You can query the current requirement separately:

```dart
final required = await gdprAdmob.isPrivacyOptionsRequired();
```

## Consent without automatic Mobile Ads initialization

Use this when another component owns Mobile Ads initialization:

```dart
final result = await gdprAdmob.requestConsent();

if (result.canRequestAds) {
  // Initialize your ads stack here.
}
```

## Consent configuration

```dart
final result = await gdprAdmob.initialize(
  configuration: const GdprConfiguration(
    tagForUnderAgeOfConsent: false,
    consentSyncId: 'signed-in-user-id',
  ),
);
```

Only set `tagForUnderAgeOfConsent` when you have determined the correct value
for the user. Consult appropriate legal guidance for age-related settings.

## Global ad request configuration

```dart
final result = await gdprAdmob.initialize(
  adRequestConfiguration: const GdprAdRequestConfiguration(
    ageRestrictedTreatment: GdprAgeRestrictedTreatment.teen,
    maxAdContentRating: GdprMaxAdContentRating.teen,
    testDeviceIds: ['GOOGLE_MOBILE_ADS_TEST_DEVICE_ID'],
  ),
);
```

The request configuration is applied before Google Mobile Ads initialization.
The first successful initialization configuration wins for a manager instance.

## Testing the UMP flow

Debug geography works only for devices registered as UMP test devices:

```dart
final result = await gdprAdmob.initialize(
  configuration: const GdprConfiguration(
    debugSettings: GdprDebugSettings(
      geography: GdprDebugGeography.eea,
      testDeviceIdentifiers: ['UMP_TEST_DEVICE_HASH'],
    ),
  ),
  adRequestConfiguration: const GdprAdRequestConfiguration(
    testDeviceIds: ['GOOGLE_MOBILE_ADS_TEST_DEVICE_ID'],
  ),
);
```

UMP test identifiers and Google Mobile Ads test-device identifiers configure
different SDK behaviors. Keep both out of your production configuration.

Reset consent only during testing:

```dart
await gdprAdmob.resetForTesting();
```

Use `showPrivacyOptionsForm()` instead of reset when production users need to
change their choices.

## Result model

`GdprConsentResult` contains:

- `status`: typed UMP consent status.
- `canRequestAds`: the authoritative ad-request eligibility flag.
- `privacyOptionsRequirementStatus`: whether an entry point is required.
- `mobileAdsStatus`: initialization outcome.
- `errors`: immutable structured errors with stage, code, and message.

Do not use a cached consent string or `status` alone to decide whether ads can
be requested. Use `canRequestAds` from a freshly completed operation.

## Testing your integration

The production class accepts replaceable consent and ads gateways, so app tests
can run without platform channels:

```dart
import 'package:gdpr_admob/gdpr_admob.dart';
import 'package:gdpr_admob/gdpr_admob_testing.dart';

final manager = GdprAdmob.withDependencies(
  consentGateway: FakeConsentGateway(),
  adsGateway: FakeAdsGateway(),
);
```

Implement `ConsentGateway` and `AdsGateway` in the test target. Keep the main
application importing only `gdpr_admob.dart`.

## Mediation

Mediation packages can pin native Google Mobile Ads SDK versions. Before
upgrading a production app, resolve dependencies and build both platforms:

```shell
flutter pub get
flutter build apk --debug
flutter build ios --debug --no-codesign
```

If CocoaPods reports incompatible Google Mobile Ads versions, update the
mediation package and its adapters together instead of overriding native pods.

## Example

The `example` app uses Google's official sample application and banner IDs. It
demonstrates startup consent, typed state, privacy options, error display, and
safe banner loading.

## Migration

Version 2.0.0 has a new typed API and newer Flutter requirements. See
[MIGRATION.md](https://github.com/Abdullah-Youssef/gdpr_admob/blob/main/MIGRATION.md)
for a complete 1.x migration guide.

## Compliance notice

This package helps integrate Google UMP but does not provide legal advice or
guarantee compliance with GDPR, ePrivacy, UK privacy law, US state privacy laws,
Google policies, or third-party ad-network requirements. Your app remains
responsible for its disclosures, configuration, legal basis, and data use.

## Contributing

Bug reports and pull requests are welcome. See
[CONTRIBUTING.md](https://github.com/Abdullah-Youssef/gdpr_admob/blob/main/CONTRIBUTING.md).

## License

GNU General Public License v3.0. See
[LICENSE](https://github.com/Abdullah-Youssef/gdpr_admob/blob/main/LICENSE).
