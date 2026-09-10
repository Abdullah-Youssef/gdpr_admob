import '../models/gdpr_configuration.dart';

/// Boundary between consent policy and a concrete mobile ads SDK.
abstract interface class AdsGateway {
  /// Applies optional global request settings and initializes Mobile Ads.
  Future<void> initialize(GdprAdRequestConfiguration? configuration);
}
