# GDPR AdMob example

This app demonstrates the production flow for `gdpr_admob` 2.0.0:

- consent information is refreshed during startup;
- a required UMP form is displayed automatically;
- Google Mobile Ads initializes only when `canRequestAds` is true;
- a privacy options button appears only when required;
- errors and typed states are visible in the UI;
- a Google test banner loads after ads are allowed.

The Android and iOS projects use Google's official sample application IDs, and
the Dart code uses official sample banner IDs. Replace all IDs before adapting
the app for production.

To test a configured AdMob application, replace the sample application ID in:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

Then create and publish the appropriate message in AdMob under **Privacy &
messaging**.

Run on Android:

```shell
flutter run -d android
```

Run on iOS:

```shell
flutter run -d ios
```
