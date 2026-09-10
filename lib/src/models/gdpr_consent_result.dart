import 'dart:collection';

/// Consent status reported by Google UMP.
enum GdprConsentStatus { notRequired, obtained, required, unknown }

/// Whether the app must expose a privacy options entry point.
enum GdprPrivacyOptionsRequirementStatus { notRequired, required, unknown }

/// Outcome of the Google Mobile Ads initialization step.
enum GdprMobileAdsStatus {
  notRequested,
  notAllowed,
  initialized,
  alreadyInitialized,
  failed,
}

/// Stage at which a consent or ads error occurred.
enum GdprErrorStage {
  consentInfoUpdate,
  consentForm,
  consentStatus,
  canRequestAds,
  privacyOptionsStatus,
  privacyOptionsForm,
  mobileAdsInitialization,
}

/// Structured error returned by `GdprAdmob` operations.
final class GdprAdmobError {
  /// Creates a structured error.
  const GdprAdmobError({
    required this.stage,
    required this.message,
    this.code,
    this.cause,
    this.stackTrace,
  });

  /// Operation stage that failed.
  final GdprErrorStage stage;

  /// Platform error code, when supplied by Google UMP.
  final int? code;

  /// Human-readable error message.
  final String message;

  /// Original error when available.
  final Object? cause;

  /// Stack trace captured at the package boundary.
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'GdprAdmobError(stage: $stage, code: $code, message: $message)';
}

/// Immutable snapshot returned after consent and ads operations.
final class GdprConsentResult {
  /// Creates a consent result.
  GdprConsentResult({
    required this.status,
    required this.canRequestAds,
    required this.privacyOptionsRequirementStatus,
    required this.mobileAdsStatus,
    List<GdprAdmobError> errors = const <GdprAdmobError>[],
  }) : errors = UnmodifiableListView<GdprAdmobError>(errors);

  /// Current UMP consent status.
  final GdprConsentStatus status;

  /// Whether Google UMP currently permits ad requests.
  final bool canRequestAds;

  /// Whether a publisher-rendered privacy options entry point is required.
  final GdprPrivacyOptionsRequirementStatus privacyOptionsRequirementStatus;

  /// Outcome of the ads initialization step.
  final GdprMobileAdsStatus mobileAdsStatus;

  /// Errors encountered while completing the operation.
  final UnmodifiableListView<GdprAdmobError> errors;

  /// Whether one or more recoverable or terminal errors occurred.
  bool get hasErrors => errors.isNotEmpty;

  /// First recorded error, or null when the operation was error-free.
  GdprAdmobError? get firstError => errors.firstOrNull;

  /// Whether the app must display a privacy options entry point.
  bool get isPrivacyOptionsRequired =>
      privacyOptionsRequirementStatus ==
      GdprPrivacyOptionsRequirementStatus.required;

  /// Returns a copy with selected fields replaced.
  GdprConsentResult copyWith({
    GdprConsentStatus? status,
    bool? canRequestAds,
    GdprPrivacyOptionsRequirementStatus? privacyOptionsRequirementStatus,
    GdprMobileAdsStatus? mobileAdsStatus,
    List<GdprAdmobError>? errors,
  }) => GdprConsentResult(
    status: status ?? this.status,
    canRequestAds: canRequestAds ?? this.canRequestAds,
    privacyOptionsRequirementStatus:
        privacyOptionsRequirementStatus ?? this.privacyOptionsRequirementStatus,
    mobileAdsStatus: mobileAdsStatus ?? this.mobileAdsStatus,
    errors: errors ?? this.errors,
  );
}
