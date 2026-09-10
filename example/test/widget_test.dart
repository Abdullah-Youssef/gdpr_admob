import 'package:example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdpr_admob/gdpr_admob.dart';
import 'package:gdpr_admob/gdpr_admob_testing.dart';

void main() {
  testWidgets('explains that the example is mobile-only', (tester) async {
    await _withTargetPlatform(TargetPlatform.linux, () async {
      await tester.pumpWidget(const MyApp());

      expect(
        find.text('This example supports Android and iOS.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('shows consent state without requesting ads when blocked', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      final consent = ExampleConsentGateway(
        status: GdprConsentStatus.required,
        allowAds: false,
      );
      final ads = ExampleAdsGateway();

      await tester.pumpWidget(
        MyApp(
          gdpr: GdprAdmob.withDependencies(
            consentGateway: consent,
            adsGateway: ads,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('required'), findsOneWidget);
      expect(find.text('notAllowed'), findsOneWidget);
      expect(find.text('Refresh consent'), findsOneWidget);
      expect(ads.initializeCalls, 0);
    });
  });

  testWidgets('shows and opens required privacy options', (tester) async {
    await _withTargetPlatform(TargetPlatform.iOS, () async {
      final consent = ExampleConsentGateway(
        privacyOptions: GdprPrivacyOptionsRequirementStatus.required,
        allowAds: false,
      );

      await tester.pumpWidget(
        MyApp(
          gdpr: GdprAdmob.withDependencies(
            consentGateway: consent,
            adsGateway: ExampleAdsGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage privacy options'), findsOneWidget);
      await tester.tap(find.text('Manage privacy options'));
      await tester.pumpAndSettle();
      expect(consent.privacyFormCalls, 1);
    });
  });
}

Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

final class ExampleConsentGateway implements ConsentGateway {
  ExampleConsentGateway({
    this.status = GdprConsentStatus.unknown,
    this.allowAds = false,
    this.privacyOptions = GdprPrivacyOptionsRequirementStatus.notRequired,
  });

  GdprConsentStatus status;
  bool allowAds;
  GdprPrivacyOptionsRequirementStatus privacyOptions;
  int privacyFormCalls = 0;

  @override
  Future<bool> canRequestAds() async => allowAds;

  @override
  Future<GdprConsentStatus> getConsentStatus() async => status;

  @override
  Future<GdprPrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async => privacyOptions;

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {}

  @override
  Future<void> requestConsentInfoUpdate(
    GdprConfiguration configuration,
  ) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> showPrivacyOptionsForm() async {
    privacyFormCalls++;
  }
}

final class ExampleAdsGateway implements AdsGateway {
  int initializeCalls = 0;

  @override
  Future<void> initialize(GdprAdRequestConfiguration? configuration) async {
    initializeCalls++;
  }
}
