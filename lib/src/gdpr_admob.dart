import 'internal/ads_gateway.dart';
import 'internal/consent_gateway.dart';
import 'internal/gateway_exception.dart';
import 'internal/google_mobile_ads_gateway.dart';
import 'internal/google_ump_consent_gateway.dart';
import 'models/gdpr_configuration.dart';
import 'models/gdpr_consent_result.dart';

/// Coordinates Google UMP consent gathering and Google Mobile Ads startup.
///
/// Create one instance for the lifetime of the application. Consent information
/// is refreshed on every call to [requestConsent] or [initialize].
final class GdprAdmob {
  /// Creates a manager backed by Google UMP and Google Mobile Ads.
  GdprAdmob()
    : this.withDependencies(
        consentGateway: GoogleUmpConsentGateway(),
        adsGateway: GoogleMobileAdsGateway(),
      );

  /// Creates a manager with replaceable platform dependencies.
  ///
  /// This constructor is intended for tests and advanced integrations.
  GdprAdmob.withDependencies({
    required ConsentGateway consentGateway,
    required AdsGateway adsGateway,
  }) : _consentGateway = consentGateway,
       _adsGateway = adsGateway;

  final ConsentGateway _consentGateway;
  final AdsGateway _adsGateway;

  Future<GdprConsentResult>? _consentOperation;
  Future<GdprMobileAdsStatus>? _adsInitializationOperation;
  bool _mobileAdsInitialized = false;

  /// Whether this instance has successfully initialized Google Mobile Ads.
  bool get isMobileAdsInitialized => _mobileAdsInitialized;

  /// Refreshes consent, shows a required form, and safely initializes ads.
  ///
  /// Ads are initialized only when Google UMP reports that ads can be
  /// requested. Concurrent calls share the same consent and ads operations.
  Future<GdprConsentResult> initialize({
    GdprConfiguration configuration = const GdprConfiguration(),
    GdprAdRequestConfiguration? adRequestConfiguration,
  }) async {
    final consentResult = await requestConsent(configuration: configuration);

    if (!consentResult.canRequestAds) {
      return consentResult.copyWith(
        mobileAdsStatus: GdprMobileAdsStatus.notAllowed,
      );
    }

    try {
      final status = await _ensureMobileAdsInitialized(adRequestConfiguration);
      return consentResult.copyWith(mobileAdsStatus: status);
    } on Object catch (error, stackTrace) {
      return consentResult.copyWith(
        mobileAdsStatus: GdprMobileAdsStatus.failed,
        errors: <GdprAdmobError>[
          ...consentResult.errors,
          _toError(GdprErrorStage.mobileAdsInitialization, error, stackTrace),
        ],
      );
    }
  }

  /// Refreshes consent information and presents a form when required.
  ///
  /// This method does not initialize Google Mobile Ads. If another consent
  /// operation is in progress, its future is returned and the first
  /// configuration wins.
  Future<GdprConsentResult> requestConsent({
    GdprConfiguration configuration = const GdprConfiguration(),
  }) {
    final inFlight = _consentOperation;
    if (inFlight != null) {
      return inFlight;
    }

    final operation = _performConsentRequest(configuration);
    _consentOperation = operation;
    return operation.whenComplete(() {
      if (identical(_consentOperation, operation)) {
        _consentOperation = null;
      }
    });
  }

  /// Reads the current UMP state without showing a form.
  Future<GdprConsentResult> getConsentSnapshot() => _readSnapshot();

  /// Returns the current consent status reported by Google UMP.
  Future<GdprConsentStatus> getConsentStatus() =>
      _consentGateway.getConsentStatus();

  /// Whether the app must expose a privacy options entry point.
  Future<bool> isPrivacyOptionsRequired() async =>
      await _consentGateway.getPrivacyOptionsRequirementStatus() ==
      GdprPrivacyOptionsRequirementStatus.required;

  /// Shows the privacy options form when Google UMP reports it is required.
  ///
  /// If no entry point is required, this returns the current snapshot without
  /// attempting to show a form.
  Future<GdprConsentResult> showPrivacyOptionsForm() async {
    final errors = <GdprAdmobError>[];

    try {
      final requirement = await _consentGateway
          .getPrivacyOptionsRequirementStatus();
      if (requirement == GdprPrivacyOptionsRequirementStatus.required) {
        await _consentGateway.showPrivacyOptionsForm();
      }
    } on Object catch (error, stackTrace) {
      errors.add(
        _toError(GdprErrorStage.privacyOptionsForm, error, stackTrace),
      );
    }

    return _readSnapshot(initialErrors: errors);
  }

  /// Resets UMP consent state for testing.
  ///
  /// Do not expose this action to production users. Use
  /// [showPrivacyOptionsForm] to let users manage their choices.
  Future<void> resetForTesting() => _consentGateway.reset();

  Future<GdprConsentResult> _performConsentRequest(
    GdprConfiguration configuration,
  ) async {
    final errors = <GdprAdmobError>[];
    var informationUpdated = false;

    try {
      await _consentGateway.requestConsentInfoUpdate(configuration);
      informationUpdated = true;
    } on Object catch (error, stackTrace) {
      errors.add(_toError(GdprErrorStage.consentInfoUpdate, error, stackTrace));
    }

    if (informationUpdated) {
      try {
        await _consentGateway.loadAndShowConsentFormIfRequired();
      } on Object catch (error, stackTrace) {
        errors.add(_toError(GdprErrorStage.consentForm, error, stackTrace));
      }
    }

    return _readSnapshot(initialErrors: errors);
  }

  Future<GdprConsentResult> _readSnapshot({
    List<GdprAdmobError> initialErrors = const <GdprAdmobError>[],
  }) async {
    final errors = <GdprAdmobError>[...initialErrors];
    var status = GdprConsentStatus.unknown;
    var canRequestAds = false;
    var privacyOptions = GdprPrivacyOptionsRequirementStatus.unknown;

    try {
      status = await _consentGateway.getConsentStatus();
    } on Object catch (error, stackTrace) {
      errors.add(_toError(GdprErrorStage.consentStatus, error, stackTrace));
    }

    try {
      canRequestAds = await _consentGateway.canRequestAds();
    } on Object catch (error, stackTrace) {
      errors.add(_toError(GdprErrorStage.canRequestAds, error, stackTrace));
    }

    try {
      privacyOptions = await _consentGateway
          .getPrivacyOptionsRequirementStatus();
    } on Object catch (error, stackTrace) {
      errors.add(
        _toError(GdprErrorStage.privacyOptionsStatus, error, stackTrace),
      );
    }

    return GdprConsentResult(
      status: status,
      canRequestAds: canRequestAds,
      privacyOptionsRequirementStatus: privacyOptions,
      mobileAdsStatus: _mobileAdsInitialized
          ? GdprMobileAdsStatus.alreadyInitialized
          : GdprMobileAdsStatus.notRequested,
      errors: errors,
    );
  }

  Future<GdprMobileAdsStatus> _ensureMobileAdsInitialized(
    GdprAdRequestConfiguration? configuration,
  ) async {
    if (_mobileAdsInitialized) {
      return GdprMobileAdsStatus.alreadyInitialized;
    }

    final inFlight = _adsInitializationOperation;
    if (inFlight != null) {
      await inFlight;
      return GdprMobileAdsStatus.alreadyInitialized;
    }

    final operation = _initializeMobileAds(configuration);
    _adsInitializationOperation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_adsInitializationOperation, operation)) {
        _adsInitializationOperation = null;
      }
    }
  }

  Future<GdprMobileAdsStatus> _initializeMobileAds(
    GdprAdRequestConfiguration? configuration,
  ) async {
    await _adsGateway.initialize(configuration);
    _mobileAdsInitialized = true;
    return GdprMobileAdsStatus.initialized;
  }

  GdprAdmobError _toError(
    GdprErrorStage stage,
    Object error,
    StackTrace stackTrace,
  ) {
    if (error case final GatewayException gatewayError) {
      return GdprAdmobError(
        stage: stage,
        code: gatewayError.code,
        message: gatewayError.message,
        cause: gatewayError.cause,
        stackTrace: stackTrace,
      );
    }

    return GdprAdmobError(
      stage: stage,
      message: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
