import '../models/gdpr_configuration.dart';
import '../models/gdpr_consent_result.dart';

/// Boundary between consent policy and a concrete consent SDK.
abstract interface class ConsentGateway {
  /// Refreshes consent information using the supplied request configuration.
  Future<void> requestConsentInfoUpdate(GdprConfiguration configuration);

  /// Loads and presents a consent form only when UMP requires one.
  Future<void> loadAndShowConsentFormIfRequired();

  /// Returns the current typed consent status.
  Future<GdprConsentStatus> getConsentStatus();

  /// Whether the ads SDK may issue ad requests now.
  Future<bool> canRequestAds();

  /// Returns whether the host app must expose privacy options.
  Future<GdprPrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus();

  /// Presents the user's privacy options form.
  Future<void> showPrivacyOptionsForm();

  /// Clears consent state for testing only.
  Future<void> reset();
}
