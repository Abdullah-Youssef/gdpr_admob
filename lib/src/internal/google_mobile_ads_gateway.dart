import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../models/gdpr_configuration.dart';
import 'ads_gateway.dart';

typedef _UpdateRequestConfiguration =
    Future<void> Function(RequestConfiguration configuration);

/// Google Mobile Ads implementation of [AdsGateway].
final class GoogleMobileAdsGateway implements AdsGateway {
  /// Creates a Google Mobile Ads gateway.
  GoogleMobileAdsGateway({
    Future<void> Function(RequestConfiguration configuration)?
    updateRequestConfiguration,
    Future<void> Function()? initializeMobileAds,
  }) : _updateRequestConfiguration =
           updateRequestConfiguration ??
           MobileAds.instance.updateRequestConfiguration,
       _initializeMobileAds =
           initializeMobileAds ??
           (() async {
             await MobileAds.instance.initialize();
           });

  final _UpdateRequestConfiguration _updateRequestConfiguration;
  final Future<void> Function() _initializeMobileAds;

  @override
  Future<void> initialize(GdprAdRequestConfiguration? configuration) async {
    if (configuration != null) {
      await _updateRequestConfiguration(
        RequestConfiguration(
          ageRestrictedTreatment: _toAgeTreatment(
            configuration.ageRestrictedTreatment,
          ),
          maxAdContentRating: _toMaxAdContentRating(
            configuration.maxAdContentRating,
          ),
          testDeviceIds: configuration.testDeviceIds.isEmpty
              ? null
              : List<String>.of(configuration.testDeviceIds),
        ),
      );
    }
    await _initializeMobileAds();
  }

  AgeRestrictedTreatment? _toAgeTreatment(
    GdprAgeRestrictedTreatment? treatment,
  ) => switch (treatment) {
    null => null,
    GdprAgeRestrictedTreatment.unspecified =>
      AgeRestrictedTreatment.unspecified,
    GdprAgeRestrictedTreatment.child => AgeRestrictedTreatment.child,
    GdprAgeRestrictedTreatment.teen => AgeRestrictedTreatment.teen,
  };

  String? _toMaxAdContentRating(GdprMaxAdContentRating? rating) =>
      switch (rating) {
        null => null,
        GdprMaxAdContentRating.unspecified => MaxAdContentRating.unspecified,
        GdprMaxAdContentRating.general => MaxAdContentRating.g,
        GdprMaxAdContentRating.parentalGuidance => MaxAdContentRating.pg,
        GdprMaxAdContentRating.teen => MaxAdContentRating.t,
        GdprMaxAdContentRating.mature => MaxAdContentRating.ma,
      };
}
