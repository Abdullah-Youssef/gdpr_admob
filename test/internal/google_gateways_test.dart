import 'package:flutter_test/flutter_test.dart';
import 'package:gdpr_admob/gdpr_admob.dart';
import 'package:gdpr_admob/src/internal/gateway_exception.dart';
import 'package:gdpr_admob/src/internal/google_mobile_ads_gateway.dart';
import 'package:gdpr_admob/src/internal/google_ump_consent_gateway.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  group('GoogleUmpConsentGateway', () {
    late FakeConsentInformation consentInformation;

    setUp(() {
      consentInformation = FakeConsentInformation();
    });

    test('maps production request parameters', () async {
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
      );

      await gateway.requestConsentInfoUpdate(
        const GdprConfiguration(
          tagForUnderAgeOfConsent: true,
          consentSyncId: 'sync-id',
        ),
      );

      final parameters = consentInformation.lastParameters;
      expect(parameters?.tagForUnderAgeOfConsent, isTrue);
      expect(parameters?.consentSyncId, 'sync-id');
      expect(parameters?.consentDebugSettings, isNull);
    });

    test('maps every debug geography', () async {
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
      );
      const expectations = <GdprDebugGeography, DebugGeography>{
        GdprDebugGeography.disabled: DebugGeography.debugGeographyDisabled,
        GdprDebugGeography.eea: DebugGeography.debugGeographyEea,
        GdprDebugGeography.regulatedUsState:
            DebugGeography.debugGeographyRegulatedUsState,
        GdprDebugGeography.other: DebugGeography.debugGeographyOther,
      };

      for (final entry in expectations.entries) {
        await gateway.requestConsentInfoUpdate(
          GdprConfiguration(
            debugSettings: GdprDebugSettings(
              geography: entry.key,
              testDeviceIdentifiers: const <String>['device'],
            ),
          ),
        );
        final settings =
            consentInformation.lastParameters?.consentDebugSettings;
        expect(settings?.debugGeography, entry.value);
        expect(settings?.testIdentifiers, <String>['device']);
      }
    });

    test('normalizes consent update failure', () async {
      consentInformation.updateError = FormError(
        errorCode: 5,
        message: 'Update failed',
      );
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
      );

      await expectLater(
        gateway.requestConsentInfoUpdate(const GdprConfiguration()),
        throwsA(
          isA<GatewayException>()
              .having((error) => error.code, 'code', 5)
              .having((error) => error.message, 'message', 'Update failed'),
        ),
      );
    });

    test('maps every consent status', () async {
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
      );
      const expectations = <ConsentStatus, GdprConsentStatus>{
        ConsentStatus.notRequired: GdprConsentStatus.notRequired,
        ConsentStatus.obtained: GdprConsentStatus.obtained,
        ConsentStatus.required: GdprConsentStatus.required,
        ConsentStatus.unknown: GdprConsentStatus.unknown,
      };

      for (final entry in expectations.entries) {
        consentInformation.status = entry.key;
        expect(await gateway.getConsentStatus(), entry.value);
      }
    });

    test('maps every privacy options status', () async {
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
      );
      const expectations =
          <
            PrivacyOptionsRequirementStatus,
            GdprPrivacyOptionsRequirementStatus
          >{
            PrivacyOptionsRequirementStatus.notRequired:
                GdprPrivacyOptionsRequirementStatus.notRequired,
            PrivacyOptionsRequirementStatus.required:
                GdprPrivacyOptionsRequirementStatus.required,
            PrivacyOptionsRequirementStatus.unknown:
                GdprPrivacyOptionsRequirementStatus.unknown,
          };

      for (final entry in expectations.entries) {
        consentInformation.privacyOptionsStatus = entry.key;
        expect(await gateway.getPrivacyOptionsRequirementStatus(), entry.value);
      }
    });

    test('delegates canRequestAds and reset', () async {
      consentInformation.canRequest = true;
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
      );

      expect(await gateway.canRequestAds(), isTrue);
      await gateway.reset();
      expect(consentInformation.resetCalls, 1);
    });

    test('loads consent form and normalizes callback errors', () async {
      var callbackError = FormError(errorCode: 8, message: 'Form failed');
      final gateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
        loadAndShowConsentForm: (listener) async {
          listener(callbackError);
        },
      );

      await expectLater(
        gateway.loadAndShowConsentFormIfRequired(),
        throwsA(
          isA<GatewayException>().having((error) => error.code, 'code', 8),
        ),
      );

      callbackError = FormError(errorCode: 0, message: 'unused');
      final successGateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
        loadAndShowConsentForm: (listener) async {
          listener(null);
        },
      );
      await successGateway.loadAndShowConsentFormIfRequired();
    });

    test('shows privacy form and normalizes callback errors', () async {
      final failingGateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
        showPrivacyOptionsForm: (listener) async {
          listener(FormError(errorCode: 11, message: 'Privacy failed'));
        },
      );

      await expectLater(
        failingGateway.showPrivacyOptionsForm(),
        throwsA(
          isA<GatewayException>().having((error) => error.code, 'code', 11),
        ),
      );

      final successGateway = GoogleUmpConsentGateway(
        consentInformation: consentInformation,
        showPrivacyOptionsForm: (listener) async {
          listener(null);
        },
      );
      await successGateway.showPrivacyOptionsForm();
    });
  });

  group('GoogleMobileAdsGateway', () {
    test('initializes without changing request configuration', () async {
      var updateCalls = 0;
      var initializeCalls = 0;
      final gateway = GoogleMobileAdsGateway(
        updateRequestConfiguration: (configuration) async {
          updateCalls++;
        },
        initializeMobileAds: () async {
          initializeCalls++;
        },
      );

      await gateway.initialize(null);

      expect(updateCalls, 0);
      expect(initializeCalls, 1);
    });

    test('maps test IDs and all request configuration enums', () async {
      final captured = <RequestConfiguration>[];
      var initializeCalls = 0;
      final gateway = GoogleMobileAdsGateway(
        updateRequestConfiguration: (configuration) async {
          captured.add(configuration);
        },
        initializeMobileAds: () async {
          initializeCalls++;
        },
      );

      const ageExpectations =
          <GdprAgeRestrictedTreatment, AgeRestrictedTreatment>{
            GdprAgeRestrictedTreatment.unspecified:
                AgeRestrictedTreatment.unspecified,
            GdprAgeRestrictedTreatment.child: AgeRestrictedTreatment.child,
            GdprAgeRestrictedTreatment.teen: AgeRestrictedTreatment.teen,
          };
      const ratingExpectations = <GdprMaxAdContentRating, String>{
        GdprMaxAdContentRating.unspecified: '',
        GdprMaxAdContentRating.general: 'G',
        GdprMaxAdContentRating.parentalGuidance: 'PG',
        GdprMaxAdContentRating.teen: 'T',
        GdprMaxAdContentRating.mature: 'MA',
      };

      for (final entry in ageExpectations.entries) {
        await gateway.initialize(
          GdprAdRequestConfiguration(
            ageRestrictedTreatment: entry.key,
            testDeviceIds: const <String>['ads-device'],
          ),
        );
        expect(captured.last.ageRestrictedTreatment, entry.value);
        expect(captured.last.testDeviceIds, <String>['ads-device']);
      }

      for (final entry in ratingExpectations.entries) {
        await gateway.initialize(
          GdprAdRequestConfiguration(maxAdContentRating: entry.key),
        );
        expect(captured.last.maxAdContentRating, entry.value);
        expect(captured.last.testDeviceIds, isNull);
      }

      await gateway.initialize(const GdprAdRequestConfiguration());
      expect(captured.last.ageRestrictedTreatment, isNull);
      expect(captured.last.maxAdContentRating, isNull);
      expect(
        initializeCalls,
        ageExpectations.length + ratingExpectations.length + 1,
      );
    });
  });
}

final class FakeConsentInformation implements ConsentInformation {
  ConsentRequestParameters? lastParameters;
  FormError? updateError;
  ConsentStatus status = ConsentStatus.unknown;
  PrivacyOptionsRequirementStatus privacyOptionsStatus =
      PrivacyOptionsRequirementStatus.unknown;
  bool canRequest = false;
  int resetCalls = 0;

  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) {
    lastParameters = params;
    final error = updateError;
    if (error == null) {
      successListener();
    } else {
      failureListener(error);
    }
  }

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<ConsentStatus> getConsentStatus() async => status;

  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async => privacyOptionsStatus;

  @override
  Future<bool> isConsentFormAvailable() async => true;

  @override
  Future<void> reset() async {
    resetCalls++;
  }
}
