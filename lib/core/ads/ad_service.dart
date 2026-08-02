import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdIds {
  AdIds._();

  static String get interstitial => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  static String get rewarded => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';
}

class AdService {
  AdService._();

  static const enabled = bool.fromEnvironment(
    'ENABLE_ADS',
    defaultValue: false,
  );

  static const rewardedXpAmount = 15;

  static Future<void> initialize() async {
    if (!enabled || kIsWeb) return;
    final consentUpdated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => consentUpdated.complete(),
      (_) => consentUpdated.complete(),
    );
    await consentUpdated.future;
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    if (await ConsentInformation.instance.canRequestAds()) {
      await MobileAds.instance.initialize();
    }
  }

  static Future<void> showPrivacyOptions() async {
    if (!enabled) return;
    await ConsentForm.showPrivacyOptionsForm((_) {});
  }

  static Future<void> recordCompletedSession() async {
    if (!enabled) return;
    final preferences = await SharedPreferences.getInstance();
    final completed =
        (preferences.getInt('completedSessionsSinceInterstitial') ?? 0) + 1;
    await preferences.setInt('completedSessionsSinceInterstitial', completed);
    final rawLastShown = preferences.getString('lastInterstitialShownAt');
    final lastShown = rawLastShown == null
        ? null
        : DateTime.tryParse(rawLastShown);
    final eligibleByTime =
        lastShown == null ||
        DateTime.now().difference(lastShown) >= const Duration(minutes: 8);
    if (completed < 3 || !eligibleByTime) return;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) async {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, _) => ad.dispose(),
          );
          await preferences.setInt('completedSessionsSinceInterstitial', 0);
          await preferences.setString(
            'lastInterstitialShownAt',
            DateTime.now().toIso8601String(),
          );
          await ad.show();
        },
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  static Future<bool> showRewarded() async {
    if (!enabled) return false;
    final completer = Completer<bool>();
    var earned = false;
    await RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, _) {
              earned = true;
            },
          );
        },
        onAdFailedToLoad: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );
    return completer.future;
  }
}
