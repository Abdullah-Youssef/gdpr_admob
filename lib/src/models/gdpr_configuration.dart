/// Regions that Google UMP can simulate on registered test devices.
enum GdprDebugGeography { disabled, eea, regulatedUsState, other }

/// Explicit test-only settings for Google UMP.
final class GdprDebugSettings {
  /// Creates UMP debug settings.
  const GdprDebugSettings({
    this.geography = GdprDebugGeography.disabled,
    this.testDeviceIdentifiers = const <String>[],
  });

  /// Region to simulate on registered test devices.
  final GdprDebugGeography geography;

  /// Hashed UMP test-device identifiers.
  final List<String> testDeviceIdentifiers;
}

/// Configuration used while requesting current consent information.
final class GdprConfiguration {
  /// Creates production consent configuration by default.
  const GdprConfiguration({
    this.tagForUnderAgeOfConsent,
    this.consentSyncId,
    this.debugSettings,
  });

  /// Whether the user should be treated as under the age of consent.
  final bool? tagForUnderAgeOfConsent;

  /// Optional identifier used by UMP to synchronize consent state.
  final String? consentSyncId;

  /// Test-only UMP settings. Keep this null in production.
  final GdprDebugSettings? debugSettings;
}

/// Age treatment applied globally to Google Mobile Ads requests.
enum GdprAgeRestrictedTreatment { unspecified, child, teen }

/// Maximum content rating applied globally to ad requests.
enum GdprMaxAdContentRating {
  unspecified,
  general,
  parentalGuidance,
  teen,
  mature,
}

/// Optional global Google Mobile Ads request configuration.
final class GdprAdRequestConfiguration {
  /// Creates an ad request configuration.
  const GdprAdRequestConfiguration({
    this.ageRestrictedTreatment,
    this.maxAdContentRating,
    this.testDeviceIds = const <String>[],
  });

  /// Age treatment for all subsequent ad requests.
  final GdprAgeRestrictedTreatment? ageRestrictedTreatment;

  /// Maximum ad content rating for all subsequent ad requests.
  final GdprMaxAdContentRating? maxAdContentRating;

  /// Google Mobile Ads test-device identifiers.
  final List<String> testDeviceIds;
}
