## 2.0.0

### Breaking changes

- Require Dart 3.10 and Flutter 3.38.1 or newer.
- Upgrade `google_mobile_ads` from 5.x to 9.1.0.
- Change `initialize()` to return `GdprConsentResult`.
- Replace string consent states with `GdprConsentStatus`.
- Replace `resetConsentStatus()` with the test-only `resetForTesting()`.
- Remove required debug geography and test identifiers from production calls.

### Added

- Add safe `canRequestAds()` gating before Mobile Ads initialization.
- Add `requestConsent()` for apps that initialize their own ads stack.
- Add typed consent, privacy options, Mobile Ads, and error states.
- Add `showPrivacyOptionsForm()` and privacy entry-point status.
- Add under-age-of-consent and consent sync configuration.
- Add global age treatment, maximum content rating, and ad test-device options.
- Add concurrent consent and Mobile Ads initialization deduplication.
- Add structured error collection while preserving cached consent eligibility.
- Add injectable gateway interfaces for application-level tests.
- Add unit tests, widget tests, coverage enforcement, and CI builds.
- Add a complete Android and iOS example with official Google test IDs.
- Add a migration guide and production/debug documentation.

### Fixed

- Do not initialize ads merely because a consent form is unavailable.
- Preserve consent-form errors instead of silently discarding them.
- Remove recursive consent-form loading.
- Await request configuration before initializing Google Mobile Ads.
- Remove deprecated child-directed treatment APIs.
- Resolve the outdated Google Mobile Ads dependency reported in issue #1.

## 1.0.3

- Update `google_mobile_ads` to 5.2.0.

## 1.0.2

- Apply package maintenance updates.

## 1.0.1

- Initial release.
