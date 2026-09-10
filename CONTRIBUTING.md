# Contributing

Thanks for helping improve `gdpr_admob`.

## Development setup

Use Dart 3.10 and Flutter 3.38.1 or newer:

```shell
flutter pub get
dart format --output=none --set-exit-if-changed lib test example/lib example/test tool
flutter analyze --fatal-infos lib test example/lib example/test tool
flutter test --coverage
dart run tool/check_coverage.dart coverage/lcov.info 90
(cd example && flutter test)
dart pub publish --dry-run
```

## Pull requests

- Keep production defaults free of debug geography and test-device IDs.
- Use `canRequestAds()` as the authority for ad-request eligibility.
- Add or update tests for every behavior change.
- Update README and CHANGELOG for public API changes.
- Do not include real AdMob application or ad-unit IDs.
- Keep platform-specific code behind the internal gateway interfaces.

## Reporting privacy-flow issues

Include Flutter, Dart, `gdpr_admob`, `google_mobile_ads`, Android/iOS, and any
mediation package versions. Remove publisher IDs and other sensitive data from
logs before posting them publicly.
