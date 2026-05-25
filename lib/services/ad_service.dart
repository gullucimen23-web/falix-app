import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static RewardedAd? _rewardedAd;

  static Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: "ca-app-pub-6519845131494268/8544916065",
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          print("REKLAM YÜKLENDİ");
        },
        onAdFailedToLoad: (error) {
          print("REKLAM YÜKLENMEDİ: $error");
        },
      ),
    );
  }

  static void showRewardedAd(Function onReward) {
    if (_rewardedAd == null) {
      print("Reklam hazır değil");
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        print("REWARD VERİLDİ");
        onReward();
      },
    );

    _rewardedAd = null;
    loadRewardedAd();
  }
}