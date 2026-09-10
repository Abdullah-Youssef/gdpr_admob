import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gdpr_admob/gdpr_admob.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.gdpr});

  final GdprAdmob? gdpr;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GDPR AdMob example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: ConsentExamplePage(gdpr: gdpr),
    );
  }
}

class ConsentExamplePage extends StatefulWidget {
  const ConsentExamplePage({super.key, this.gdpr});

  final GdprAdmob? gdpr;

  @override
  State<ConsentExamplePage> createState() => _ConsentExamplePageState();
}

class _ConsentExamplePageState extends State<ConsentExamplePage> {
  late final GdprAdmob _gdpr;
  GdprConsentResult? _result;
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _isLoading = true;
  String? _bannerError;

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  String get _bannerAdUnitId => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ca-app-pub-3940256099942544/6300978111',
    TargetPlatform.iOS => 'ca-app-pub-3940256099942544/2934735716',
    _ => '',
  };

  @override
  void initState() {
    super.initState();
    _gdpr = widget.gdpr ?? GdprAdmob();
    if (_isMobile) {
      _initialize();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initialize() async {
    _setLoading();
    final result = await _gdpr.initialize();
    if (!mounted) return;
    _applyResult(result);
  }

  Future<void> _showPrivacyOptions() async {
    _setLoading();
    var result = await _gdpr.showPrivacyOptionsForm();
    if (result.canRequestAds && !_gdpr.isMobileAdsInitialized) {
      result = await _gdpr.initialize();
    }
    if (!mounted) return;
    _applyResult(result);
  }

  void _setLoading() {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
  }

  void _applyResult(GdprConsentResult result) {
    final bannerToDispose = result.canRequestAds ? null : _bannerAd;
    setState(() {
      _result = result;
      _isLoading = false;
      if (!result.canRequestAds) {
        _bannerAd = null;
        _isBannerLoaded = false;
      }
    });
    bannerToDispose?.dispose();

    if (result.canRequestAds && _bannerAd == null) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    final banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted || !identical(_bannerAd, ad)) {
            ad.dispose();
            return;
          }
          setState(() {
            _isBannerLoaded = true;
            _bannerError = null;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted || !identical(_bannerAd, ad)) return;
          setState(() {
            _bannerAd = null;
            _isBannerLoaded = false;
            _bannerError = error.message;
          });
        },
      ),
    );

    setState(() {
      _bannerAd = banner;
      _isBannerLoaded = false;
    });
    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final banner = _bannerAd;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('GDPR AdMob example'),
      ),
      body: !_isMobile
          ? const Center(child: Text('This example supports Android and iOS.'))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_isLoading) const LinearProgressIndicator(),
                const SizedBox(height: 24),
                _StatusTile(
                  label: 'Consent status',
                  value: result?.status.name ?? 'loading',
                ),
                _StatusTile(
                  label: 'Can request ads',
                  value: '${result?.canRequestAds ?? false}',
                ),
                _StatusTile(
                  label: 'Mobile Ads',
                  value: result?.mobileAdsStatus.name ?? 'not initialized',
                ),
                _StatusTile(
                  label: 'Privacy options',
                  value:
                      result?.privacyOptionsRequirementStatus.name ?? 'unknown',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoading ? null : _initialize,
                  child: const Text('Refresh consent'),
                ),
                if (result?.isPrivacyOptionsRequired ?? false)
                  OutlinedButton(
                    onPressed: _isLoading ? null : _showPrivacyOptions,
                    child: const Text('Manage privacy options'),
                  ),
                for (final error in result?.errors ?? <GdprAdmobError>[])
                  Text(
                    '${error.stage.name}: ${error.message}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_bannerError case final error?)
                  Text(
                    'Banner: $error',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: banner == null || !_isBannerLoaded
          ? null
          : SafeArea(
              child: SizedBox(
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
                child: AdWidget(ad: banner),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(value),
  );
}
