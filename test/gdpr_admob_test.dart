import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gdpr_admob/gdpr_admob.dart';
import 'package:gdpr_admob/gdpr_admob_testing.dart';
import 'package:gdpr_admob/src/internal/gateway_exception.dart';

void main() {
  group('GdprAdmob.initialize', () {
    late FakeConsentGateway consent;
    late FakeAdsGateway ads;
    late GdprAdmob gdpr;

    setUp(() {
      consent = FakeConsentGateway();
      ads = FakeAdsGateway();
      gdpr = GdprAdmob.withDependencies(
        consentGateway: consent,
        adsGateway: ads,
      );
    });

    test('gathers consent and initializes ads when allowed', () async {
      consent
        ..status = GdprConsentStatus.obtained
        ..adsAllowed = true
        ..privacyOptions = GdprPrivacyOptionsRequirementStatus.required;
      const adConfiguration = GdprAdRequestConfiguration(
        ageRestrictedTreatment: GdprAgeRestrictedTreatment.teen,
        maxAdContentRating: GdprMaxAdContentRating.teen,
        testDeviceIds: <String>['ads-device'],
      );

      final result = await gdpr.initialize(
        adRequestConfiguration: adConfiguration,
      );

      expect(consent.updateCalls, 1);
      expect(consent.formCalls, 1);
      expect(ads.initializeCalls, 1);
      expect(ads.lastConfiguration, same(adConfiguration));
      expect(result.status, GdprConsentStatus.obtained);
      expect(result.canRequestAds, isTrue);
      expect(result.isPrivacyOptionsRequired, isTrue);
      expect(result.mobileAdsStatus, GdprMobileAdsStatus.initialized);
      expect(result.errors, isEmpty);
      expect(gdpr.isMobileAdsInitialized, isTrue);
    });

    test('does not initialize ads when UMP does not allow requests', () async {
      consent
        ..status = GdprConsentStatus.required
        ..adsAllowed = false;

      final result = await gdpr.initialize();

      expect(ads.initializeCalls, 0);
      expect(result.mobileAdsStatus, GdprMobileAdsStatus.notAllowed);
      expect(gdpr.isMobileAdsInitialized, isFalse);
    });

    test('uses cached consent after update failure', () async {
      consent
        ..updateError = const GatewayException(
          code: 7,
          message: 'Network unavailable',
        )
        ..status = GdprConsentStatus.obtained
        ..adsAllowed = true;

      final result = await gdpr.initialize();

      expect(consent.formCalls, 0);
      expect(ads.initializeCalls, 1);
      expect(result.canRequestAds, isTrue);
      expect(result.mobileAdsStatus, GdprMobileAdsStatus.initialized);
      expect(result.errors, hasLength(1));
      expect(result.firstError?.stage, GdprErrorStage.consentInfoUpdate);
      expect(result.firstError?.code, 7);
      expect(result.firstError?.message, 'Network unavailable');
    });

    test('reports a form error and still follows canRequestAds', () async {
      consent
        ..formError = const GatewayException(code: 3, message: 'Form failed')
        ..adsAllowed = true;

      final result = await gdpr.initialize();

      expect(ads.initializeCalls, 1);
      expect(result.firstError?.stage, GdprErrorStage.consentForm);
      expect(result.firstError?.code, 3);
    });

    test('reports ads initialization failure without throwing', () async {
      consent.adsAllowed = true;
      ads.error = StateError('Ads failed');

      final result = await gdpr.initialize();

      expect(result.mobileAdsStatus, GdprMobileAdsStatus.failed);
      expect(result.firstError?.stage, GdprErrorStage.mobileAdsInitialization);
      expect(gdpr.isMobileAdsInitialized, isFalse);
    });

    test('initializes Mobile Ads only once', () async {
      consent.adsAllowed = true;

      final first = await gdpr.initialize();
      final second = await gdpr.initialize();

      expect(first.mobileAdsStatus, GdprMobileAdsStatus.initialized);
      expect(second.mobileAdsStatus, GdprMobileAdsStatus.alreadyInitialized);
      expect(consent.updateCalls, 2);
      expect(ads.initializeCalls, 1);
    });

    test('deduplicates concurrent consent and ads operations', () async {
      consent
        ..adsAllowed = true
        ..updateBlocker = Completer<void>();
      ads.blocker = Completer<void>();

      final first = gdpr.initialize();
      final second = gdpr.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(consent.updateCalls, 1);
      consent.updateBlocker?.complete();
      await Future<void>.delayed(Duration.zero);
      expect(ads.initializeCalls, 1);
      ads.blocker?.complete();

      final results = await Future.wait(<Future<GdprConsentResult>>[
        first,
        second,
      ]);
      expect(consent.formCalls, 1);
      expect(ads.initializeCalls, 1);
      expect(results.every((result) => result.canRequestAds), isTrue);
    });
  });

  group('GdprAdmob consent operations', () {
    late FakeConsentGateway consent;
    late FakeAdsGateway ads;
    late GdprAdmob gdpr;

    setUp(() {
      consent = FakeConsentGateway();
      ads = FakeAdsGateway();
      gdpr = GdprAdmob.withDependencies(
        consentGateway: consent,
        adsGateway: ads,
      );
    });

    test('forwards production and debug consent configuration', () async {
      const configuration = GdprConfiguration(
        tagForUnderAgeOfConsent: true,
        consentSyncId: 'account-42',
        debugSettings: GdprDebugSettings(
          geography: GdprDebugGeography.eea,
          testDeviceIdentifiers: <String>['ump-device'],
        ),
      );

      await gdpr.requestConsent(configuration: configuration);

      expect(consent.lastConfiguration, same(configuration));
      expect(ads.initializeCalls, 0);
    });

    test('reads a snapshot without updating or showing a form', () async {
      consent
        ..status = GdprConsentStatus.notRequired
        ..adsAllowed = true
        ..privacyOptions = GdprPrivacyOptionsRequirementStatus.notRequired;

      final result = await gdpr.getConsentSnapshot();

      expect(consent.updateCalls, 0);
      expect(consent.formCalls, 0);
      expect(result.status, GdprConsentStatus.notRequired);
      expect(result.canRequestAds, isTrue);
      expect(result.errors, isEmpty);
    });

    test(
      'keeps reading other snapshot fields after individual errors',
      () async {
        consent
          ..statusError = StateError('status')
          ..canRequestAdsError = StateError('permission')
          ..privacyStatusError = StateError('privacy');

        final result = await gdpr.getConsentSnapshot();

        expect(result.status, GdprConsentStatus.unknown);
        expect(result.canRequestAds, isFalse);
        expect(result.errors.map((error) => error.stage), <GdprErrorStage>[
          GdprErrorStage.consentStatus,
          GdprErrorStage.canRequestAds,
          GdprErrorStage.privacyOptionsStatus,
        ]);
      },
    );

    test('shows privacy options when required and refreshes state', () async {
      consent
        ..privacyOptions = GdprPrivacyOptionsRequirementStatus.required
        ..statusAfterPrivacyForm = GdprConsentStatus.obtained
        ..adsAllowedAfterPrivacyForm = true;

      final result = await gdpr.showPrivacyOptionsForm();

      expect(consent.privacyFormCalls, 1);
      expect(result.status, GdprConsentStatus.obtained);
      expect(result.canRequestAds, isTrue);
    });

    test('does not show privacy options when not required', () async {
      consent.privacyOptions = GdprPrivacyOptionsRequirementStatus.notRequired;

      final result = await gdpr.showPrivacyOptionsForm();

      expect(consent.privacyFormCalls, 0);
      expect(result.hasErrors, isFalse);
    });

    test('returns privacy form errors', () async {
      consent
        ..privacyOptions = GdprPrivacyOptionsRequirementStatus.required
        ..privacyFormError = const GatewayException(
          code: 9,
          message: 'Privacy form failed',
        );

      final result = await gdpr.showPrivacyOptionsForm();

      expect(result.firstError?.stage, GdprErrorStage.privacyOptionsForm);
      expect(result.firstError?.code, 9);
    });

    test('exposes status and privacy convenience methods', () async {
      consent
        ..status = GdprConsentStatus.required
        ..privacyOptions = GdprPrivacyOptionsRequirementStatus.required;

      expect(await gdpr.getConsentStatus(), GdprConsentStatus.required);
      expect(await gdpr.isPrivacyOptionsRequired(), isTrue);
    });

    test('resetForTesting delegates to UMP', () async {
      await gdpr.resetForTesting();

      expect(consent.resetCalls, 1);
    });

    test('result errors are immutable', () async {
      final result = await gdpr.getConsentSnapshot();

      expect(
        () => result.errors.add(
          const GdprAdmobError(
            stage: GdprErrorStage.consentForm,
            message: 'No mutation',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}

final class FakeConsentGateway implements ConsentGateway {
  int updateCalls = 0;
  int formCalls = 0;
  int privacyFormCalls = 0;
  int resetCalls = 0;

  GdprConfiguration? lastConfiguration;
  GdprConsentStatus status = GdprConsentStatus.unknown;
  bool adsAllowed = false;
  GdprPrivacyOptionsRequirementStatus privacyOptions =
      GdprPrivacyOptionsRequirementStatus.unknown;

  GdprConsentStatus? statusAfterPrivacyForm;
  bool? adsAllowedAfterPrivacyForm;
  Completer<void>? updateBlocker;

  Object? updateError;
  Object? formError;
  Object? statusError;
  Object? canRequestAdsError;
  Object? privacyStatusError;
  Object? privacyFormError;

  @override
  Future<void> requestConsentInfoUpdate(GdprConfiguration configuration) async {
    updateCalls++;
    lastConfiguration = configuration;
    await updateBlocker?.future;
    if (updateError case final error?) throw error;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    formCalls++;
    if (formError case final error?) throw error;
  }

  @override
  Future<GdprConsentStatus> getConsentStatus() async {
    if (statusError case final error?) throw error;
    return status;
  }

  @override
  Future<bool> canRequestAds() async {
    if (canRequestAdsError case final error?) throw error;
    return adsAllowed;
  }

  @override
  Future<GdprPrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async {
    if (privacyStatusError case final error?) throw error;
    return privacyOptions;
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    privacyFormCalls++;
    if (privacyFormError case final error?) throw error;
    status = statusAfterPrivacyForm ?? status;
    adsAllowed = adsAllowedAfterPrivacyForm ?? adsAllowed;
  }

  @override
  Future<void> reset() async {
    resetCalls++;
  }
}

final class FakeAdsGateway implements AdsGateway {
  int initializeCalls = 0;
  GdprAdRequestConfiguration? lastConfiguration;
  Completer<void>? blocker;
  Object? error;

  @override
  Future<void> initialize(GdprAdRequestConfiguration? configuration) async {
    initializeCalls++;
    lastConfiguration = configuration;
    await blocker?.future;
    if (error case final initializationError?) throw initializationError;
  }
}
