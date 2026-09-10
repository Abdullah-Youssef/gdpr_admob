import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/gdpr_configuration.dart';
import '../models/gdpr_consent_result.dart';
import 'consent_gateway.dart';
import 'gateway_exception.dart';

typedef _ConsentFormOperation =
    Future<void> Function(OnConsentFormDismissedListener listener);

/// Google UMP implementation of [ConsentGateway].
final class GoogleUmpConsentGateway implements ConsentGateway {
  /// Creates a Google UMP gateway.
  GoogleUmpConsentGateway({
    ConsentInformation? consentInformation,
    Future<void> Function(OnConsentFormDismissedListener listener)?
    loadAndShowConsentForm,
    Future<void> Function(OnConsentFormDismissedListener listener)?
    showPrivacyOptionsForm,
  }) : _consentInformation = consentInformation ?? ConsentInformation.instance,
       _loadAndShowConsentForm =
           loadAndShowConsentForm ??
           ConsentForm.loadAndShowConsentFormIfRequired,
       _showPrivacyOptionsForm =
           showPrivacyOptionsForm ?? ConsentForm.showPrivacyOptionsForm;

  final ConsentInformation _consentInformation;
  final _ConsentFormOperation _loadAndShowConsentForm;
  final _ConsentFormOperation _showPrivacyOptionsForm;

  @override
  Future<void> requestConsentInfoUpdate(GdprConfiguration configuration) {
    final completer = Completer<void>();
    final debugSettings = configuration.debugSettings;
    final parameters = ConsentRequestParameters(
      tagForUnderAgeOfConsent: configuration.tagForUnderAgeOfConsent,
      consentSyncId: configuration.consentSyncId,
      consentDebugSettings: debugSettings == null
          ? null
          : ConsentDebugSettings(
              debugGeography: _toGoogleGeography(debugSettings.geography),
              testIdentifiers: List<String>.of(
                debugSettings.testDeviceIdentifiers,
              ),
            ),
    );

    _consentInformation.requestConsentInfoUpdate(
      parameters,
      () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(_fromFormError(error));
        }
      },
    );
    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    FormError? callbackError;
    await _loadAndShowConsentForm((error) {
      callbackError = error;
    });
    if (callbackError case final error?) {
      throw _fromFormError(error);
    }
  }

  @override
  Future<GdprConsentStatus> getConsentStatus() async =>
      _toConsentStatus(await _consentInformation.getConsentStatus());

  @override
  Future<bool> canRequestAds() => _consentInformation.canRequestAds();

  @override
  Future<GdprPrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async => _toPrivacyOptionsStatus(
    await _consentInformation.getPrivacyOptionsRequirementStatus(),
  );

  @override
  Future<void> showPrivacyOptionsForm() async {
    FormError? callbackError;
    await _showPrivacyOptionsForm((error) {
      callbackError = error;
    });
    if (callbackError case final error?) {
      throw _fromFormError(error);
    }
  }

  @override
  Future<void> reset() => _consentInformation.reset();

  DebugGeography _toGoogleGeography(GdprDebugGeography geography) =>
      switch (geography) {
        GdprDebugGeography.disabled => DebugGeography.debugGeographyDisabled,
        GdprDebugGeography.eea => DebugGeography.debugGeographyEea,
        GdprDebugGeography.regulatedUsState =>
          DebugGeography.debugGeographyRegulatedUsState,
        GdprDebugGeography.other => DebugGeography.debugGeographyOther,
      };

  GdprConsentStatus _toConsentStatus(ConsentStatus status) => switch (status) {
    ConsentStatus.notRequired => GdprConsentStatus.notRequired,
    ConsentStatus.obtained => GdprConsentStatus.obtained,
    ConsentStatus.required => GdprConsentStatus.required,
    ConsentStatus.unknown => GdprConsentStatus.unknown,
  };

  GdprPrivacyOptionsRequirementStatus _toPrivacyOptionsStatus(
    PrivacyOptionsRequirementStatus status,
  ) => switch (status) {
    PrivacyOptionsRequirementStatus.notRequired =>
      GdprPrivacyOptionsRequirementStatus.notRequired,
    PrivacyOptionsRequirementStatus.required =>
      GdprPrivacyOptionsRequirementStatus.required,
    PrivacyOptionsRequirementStatus.unknown =>
      GdprPrivacyOptionsRequirementStatus.unknown,
  };

  GatewayException _fromFormError(FormError error) => GatewayException(
    code: error.errorCode,
    message: error.message,
    cause: error,
  );
}
